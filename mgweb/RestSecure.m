RestSecure ; mgweb-server Back-end for interoperability with Rest-Secure-based front end
 ;
 ;----------------------------------------------------------------------------
 ;| RestSecure: mgweb-server Interface for Rest-Secure applications          |
 ;|                                                                          |
 ;| Copyright (c) 2022 M/Gateway Developments Ltd,                           |
 ;| Redhill, Surrey UK.                                                      |
 ;| All rights reserved.                                                     |
 ;|                                                                          |
 ;| http://www.mgateway.com                                                  |
 ;| Email: rtweed@mgateway.com                                               |
 ;|                                                                          |
 ;|                                                                          |
 ;| Licensed under the Apache License, Version 2.0 (the "License");          |
 ;| you may not use this file except in compliance with the License.         |
 ;| You may obtain a copy of the License at                                  |
 ;|                                                                          |
 ;|     http://www.apache.org/licenses/LICENSE-2.0                           |
 ;|                                                                          |
 ;| Unless required by applicable law or agreed to in writing, software      |
 ;| distributed under the License is distributed on an "AS IS" BASIS,        |
 ;| WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. |
 ;| See the License for the specific language governing permissions and      |
 ;|  limitations under the License.                                          |
 ;----------------------------------------------------------------------------
 ;
 ; 17 August 2022
 ;
 QUIT
 ;
deleteExpiredIdTokens
 ;
 n expires,idToken,now,uuid
 ;
 ; Expired Id and Refresh Tokens
 ;
 l +^RestSecure
 s now=$$convertDateToSeconds($h)
 s uuid=""
 f  s uuid=$o(^RestSecure("refreshToken",uuid)) q:uuid=""  d
 . s expires=$g(^RestSecure("refreshToken",uuid,"expires"))
 . i expires<now d
 . . s idToken=$g(^RestSecure("refreshToken",uuid,"idToken"))
 . . i idToken'="" k ^RestSecure("idToken",idToken)
 . . k ^RestSecure("refreshToken",uuid)
 ;
 ; remove stranded idTokens
 ;
 s uuid=""
 f  s uuid=$o(^RestSecure("idToken",uuid)) q:uuid=""  d
 . s refreshToken=$g(^RestSecure("idToken",uuid,"refreshToken"))
 . i refreshToken'="",'$d(^RestSecure("refreshToken",refreshToken)) k ^RestSecure("idToken",uuid)
 l -^RestSecure
 QUIT
 ;
returnAuthToken(req,headers) ;
 ;
 n token
 ;
 s token=$g(req("headers","x_authorization"))
 i token="" QUIT
 s token=$p(token,"Bearer ",2)
 i token="" QUIT
 s headers("X-Request-ID")=token
 QUIT
 ;
getAuthToken(req) ;
 ;
 n token
 ;
 s token=$g(req("headers","x_authorization"))
 i token="" QUIT ""
 s token=$p(token,"Bearer ",2)
 QUIT token
 ;
getAuthorization(req) ;
 ;
 n token
 ;
 s token=$g(req("headers","authorization"))
 i token="" QUIT ""
 s token=$p(token,"Bearer ",2)
 QUIT token
 ;
deleteExpiredJWTTokens
 ;
 n expires,now,refreshToken,uuid
 ;
 l +^RestSecure
 s now=$$convertDateToSeconds($h)
 s uuid=""
 f  s uuid=$o(^RestSecure("jwt",uuid)) q:uuid=""  d
 . s refreshToken=$g(^RestSecure("jwt",uuid,"refreshToken"))
 . s expires=$g(^RestSecure("jwt",uuid,"expires"))
 . i expires<now k ^RestSecure("jwt",uuid)
 s refreshToken=""
 f  s refreshToken=$o(^RestSecure("refreshToken",refreshToken)) q:refreshToken=""  d
 . s expires=$g(^RestSecure("refreshToken",refreshToken,"expires"))
 . i expires<now k ^RestSecure("refreshToken",refreshToken)
 l -^RestSecure
 QUIT
 ;
getRefreshToken(req,data) ;
 ;
 k data
 n id,token
 ;
 d deleteExpiredJWTTokens
 s token=$g(req("headers","cookie"))
 i token="" QUIT 0
 s token=$p(token,"RefreshToken=",2)
 i token="" QUIT 0
 s id=$g(^RestSecure("refreshToken",token,"id"))
 i id="" QUIT 0
 s data("refreshToken")=token
 s data("id")=id
 QUIT 1
 ;
validJWT(req,errors,claims) ;
 ;
 n key,jwt,rsjwt,uuid
 ;
 k claims
 d deleteExpiredJWTTokens
 ;
 ; was a jwt returned as the authorization header?
 ;
 s jwt=$$getAuthorization(.req)
 i jwt="" d  QUIT 0
 . s errors("error")="Missing Authorization Header"
 ;
 ; does the jwt have a uuid to link it to back-end copy?
 ;
 s uuid=$$getClaim^%zmgwebJWT(jwt,"uuid")
 i uuid="" d  QUIT 0
 . s errors("error")="Invalid JWT 1"
 ;
 ; is there a back-end copy jwt with that UUID?
 ;
 s rsjwt=$g(^RestSecure("jwt",uuid,"jwt"))
 i rsjwt="" d  QUIT 0
 . s errors("error")="Invalid or expired JWT"
 ;
 ; do the JWTs match?
 ;
 i jwt'=rsjwt d  QUIT 0
 . s errors("error")="Invalid JWT 3"
 ;
 ; retrieve the key
 ;
 s key=$g(^RestSecure("jwt",uuid,"key"))
 i key="" d  QUIT 0
 . s errors("error")="Invalid or Expired JWT 2"
 ;
 ; authenticate the incoming JWT using the key
 ;
 i '$$authenticateJWT^%zmgwebJWT(jwt,key,.reason) d  QUIT 0
 . s errors("error")=reason
 . s ^rob("update","reason")=reason
 ;
 ; JWT is OK!
 ;
 m claims=^RestSecure("jwt",uuid,"claims")
 s claims("id")=^RestSecure("jwt",uuid,"id")
 s claims("uuid")=uuid
 ;
 QUIT 1
 ;
createJWT(id,claims,options,headers) ;
 ;
 n claim,field,jwt,key,now,refreshToken,sameSite,secure,uuid
 ;
 i '$g(options("jwtExpiryTime")) s options("jwtExpiryTime")=300
 i '$g(options("refreshTokenExpiryTime")) s options("refreshTokenExpiryTime")=86400
 s secure="; Secure"
 i $g(options("secureCookie"))=0 secure=""
 s sameSite="; SameSite=Strict"
 i $g(options("sameSiteCookie"))=0 sameSite=""
 d deleteExpiredJWTTokens
 s key=$$createJWTUid^%zmgwebJWT()
 s uuid=$$createJWTUid^%zmgwebJWT()
 s refreshToken=$$createJWTUid^%zmgwebJWT()
 s now=$$convertDateToSeconds($h)
 ;
 l +^RestSecure
 s ^RestSecure("refreshToken",refreshToken,"expires")=now+options("refreshTokenExpiryTime")
 s ^RestSecure("refreshToken",refreshToken,"id")=$g(id)
 s ^RestSecure("refreshToken",refreshToken,"jwtExpiryTime")=options("jwtExpiryTime")
 s ^RestSecure("jwt",uuid,"key")=key
 s ^RestSecure("jwt",uuid,"id")=id
 s ^RestSecure("jwt",uuid,"created")=now
 s ^RestSecure("jwt",uuid,"expires")=now+options("jwtExpiryTime")
 s ^RestSecure("jwt",uuid,"refreshToken")=refreshToken
 s claim=""
 f  s claim=$o(claims(claim)) q:claim=""  d
 . n claimValue
 . s claimValue=$g(claims(claim))
 . s ^RestSecure("jwt",uuid,"claims",claim)=claimValue
 s claims("uuid")=uuid
 s claims("iss")="RestSecure"
 s jwt=$$createJWT^%zmgwebJWT(.claims,options("jwtExpiryTime"),key)
 s ^RestSecure("jwt",uuid,"jwt")=jwt
 l -^RestSecure
 ;
 s headers("Authorization")=jwt
 s headers("Set-Cookie")="RefreshToken="_refreshToken_"; Path=/; HttpOnly; Max-Age="_options("refreshTokenExpiryTime")_secure_sameSite_";"
 QUIT
 ;
refreshJWT(id,refreshToken,inClaims,headers) ;
 ;
 n claim,claims,expiryTime,field,jwt,key,now,uuid
 ;
 m claims=inClaims
 d deleteExpiredJWTTokens
 s key=$$createJWTUid^%zmgwebJWT()
 s uuid=$$createJWTUid^%zmgwebJWT()
 s now=$$convertDateToSeconds($h)
 ;
 s expiryTime=$g(^RestSecure("refreshToken",refreshToken,"jwtExpiryTime"))
 i expiryTime="" s expiryTime=300
 ;
 l +^RestSecure
 s ^RestSecure("jwt",uuid,"key")=key
 s ^RestSecure("jwt",uuid,"id")=id
 s ^RestSecure("jwt",uuid,"created")=now
 s ^RestSecure("jwt",uuid,"expires")=now+expiryTime
 s ^RestSecure("jwt",uuid,"refreshToken")=$g(refreshToken)
 s claim=""
 f  s claim=$o(claims(claim)) q:claim=""  d
 . n claimValue
 . s claimValue=$g(claims(claim))
 . s ^RestSecure("jwt",uuid,"claims",claim)=claimValue
 s claims("uuid")=uuid
 s claims("iss")="RestSecure"
 s jwt=$$createJWT^%zmgwebJWT(.claims,expiryTime,key)
 s ^RestSecure("jwt",uuid,"jwt")=jwt
 l -^RestSecure
 ;
 s headers("Authorization")=jwt
 QUIT
 ;
refreshIdToken(id,refreshToken,headers) ;
 ;
 n uuid
 ;
 d deleteExpiredIdTokens
 s uuid=$$createJWTUid^%zmgwebJWT()
 ;
 l +^RestSecure
 s ^RestSecure("idToken",uuid,"refreshToken")=refreshToken
 s ^RestSecure("refreshToken",refreshToken,"idToken")=uuid
 l -^RestSecure
 ;
 s headers("Authorization")=uuid
 QUIT
 ;
updateJWT(req,res,headers,errors,expiryTime) ;
 ;
 n claims,jwt,key,now,uuid
 ;
 s jwt=$$getAuthorization(.req)
 i jwt="" d  QUIT
 . s errors("error")="Missing Authorization Header"
 s ^rob("update","jwt")=jwt
 s uuid=$$getClaim^%zmgwebJWT(jwt,"uuid")
 i uuid="" d  QUIT 0
 . s errors("error")="Invalid JWT 1"
 s ^rob("update","uuid")=uuid
 i '$g(expiryTime) s expiryTime=86400
 d deleteExpiredJWTTokens
 i '$d(^RestSecure("jwt",uuid)) d  QUIT 0
 . s errors("error")="Invalid or Expired JWT 1"
 i jwt'=$g(^RestSecure("jwt",uuid,"jwt")) d  QUIT 0
 . s errors("error")="Invalid JWT 2"
 s key=$g(^RestSecure("jwt",uuid,"key"))
 i key="" d  QUIT 0
 . s errors("error")="Invalid or Expired JWT 2"
 s ^rob("update","key")=key
 i '$$authenticateJWT^%zmgwebJWT(jwt,key,.reason) d  QUIT 0
 . s errors("error")=reason
 . s ^rob("update","reason")=reason
 ;
 s now=$$convertDateToSeconds($h)
 i now'=$g(^RestSecure("jwt",uuid,"now")) d
 . l +^RestSecure
 . s ^RestSecure("jwt",uuid,"expires")=now+expiryTime
 . m claims=req("jwt_claims")
 . s claims("uuid")=uuid
 . s claims("iss")="RestSecure"
 . s jwt=$$createJWT^%zmgwebJWT(.claims,expiryTime,key)
 . s ^RestSecure("jwt",uuid,"jwt")=jwt
 . l -^RestSecure
 s headers("Authorization")=jwt
 d returnAuthToken^RestSecure(.req,.headers)
 QUIT 1
 ;
createIdToken(id,options,headers) ;
 ;
 n now,refreshToken,sameSite,secure,uuid
 ;
 i '$g(options("refreshTokenExpiryTime")) s options("refreshTokenExpiryTime")=86400
 s secure="; Secure"
 i $g(options("secureCookie"))=0 secure=""
 s sameSite="; SameSite=Strict"
 i $g(options("sameSiteCookie"))=0 sameSite=""
 d deleteExpiredIdTokens
 s uuid=$$createJWTUid^%zmgwebJWT()
 s now=$$convertDateToSeconds($h)
 s refreshToken=$$createJWTUid^%zmgwebJWT()
 ;
 l +^RestSecure
 s ^RestSecure("refreshToken",refreshToken,"expires")=now+options("refreshTokenExpiryTime")
 s ^RestSecure("refreshToken",refreshToken,"expiryTime")=options("refreshTokenExpiryTime")
 s ^RestSecure("refreshToken",refreshToken,"id")=$g(id)
 s ^RestSecure("refreshToken",refreshToken,"idToken")=uuid
 ;
 s ^RestSecure("idToken",uuid,"refreshToken")=refreshToken
 l -^RestSecure
 ;
 s headers("Authorization")=uuid
 s headers("Set-Cookie")="RefreshToken="_refreshToken_"; Path=/; HttpOnly; Max-Age="_options("refreshTokenExpiryTime")_secure_sameSite_";"
 QUIT
 ;
validIdToken(req,errors,data) ;
 ;
 n error,idToken,key,refreshToken
 ;
 k data
 d deleteExpiredIdTokens
 ;
 ; was an idToken returned as the authorization header?
 ;
 s error=0
 s idToken=$$getAuthorization(.req)
 i idToken="" d  i error QUIT 0
 . ; 
 . ; See if the RefreshToken cookie is valid - if so, allow this through
 . ; by creating a new temporary idToken
 . ;
 . n crt,newUuid
 . s cookie=$g(req("headers","cookie"))
 . i cookie="" d  QUIT 
 . . s errors("error")="No cookie"
 . . s error=1
 . ;
 . s crt=$p(cookie,"RefreshToken=",2)
 . i crt="" d  QUIT
 . . s errors("error")="Invalid cookie"
 . . s error=1
 . i '$d(^RestSecure("refreshToken",crt) d  QUIT
 . . s errors("error")="Unrecognised cookie"
 . . s error=1
 . s newUuid=$$createJWTUid^%zmgwebJWT()
 . l +^RestSecure
 . s ^RestSecure("idToken",newUuid,"refreshToken")=crt
 . l -^RestSecure
 . idToken=newUuid
 ;
 ; is there a back-end copy idToken with the same UUID?
 ;
 i '$d(^RestSecure("idToken",idToken)) d  QUIT 0
 . s errors("error")="Invalid or expired authorization token"
 ;
 ; idToken is OK!
 ;
 s refreshToken=$g(^RestSecure("idToken",idToken,"refreshToken"))
 i refreshToken="" d  QUIT 0
 . s errors("error")="Invalid or expired authorization token"
 ;
 s data("id")=$g(^RestSecure("refreshToken",refreshToken,"id"))
 s data("idToken")=idToken
 s data("refreshToken")=refreshToken
 ;
 QUIT 1
 ;
updateIdToken(idToken,refreshToken,headers,errors)
 ;
 n expiryTime,newUuid
 ;
 i idToken="" d  QUIT
 . s errors("error")="Missing idToken"
 i refreshToken="" d  QUIT 0
 . s errors("error")="Missing Refresh Token"
 s newUuid=$$createJWTUid^%zmgwebJWT()
 ;
 l +^RestSecure
 k ^RestSecure("idToken",idToken);
 s ^RestSecure("idToken",newUuid,"refreshToken")=refreshToken
 s ^RestSecure("refreshToken",refreshToken,"idToken")=newUuid
 l -^RestSecure
 ;
 s headers("Authorization")=newUuid
 QUIT
 ;
convertDateToSeconds(hdate)
 Q (hdate*86400)+$p(hdate,",",2)
 ;