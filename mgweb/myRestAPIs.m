 ;
 ; APIs
 ;
refreshJWT(req) ;
 ;
 k ^rob("refreshJWT") m ^rob("refreshJWT")=req
 n claims,data,errors,headers,id,ok
 ;
 s ok=$$getRefreshToken^RestSecure(.req,.data)
 i 'ok d  QUIT $$errorResponse^%zmgweb(.errors)
 . s errors("error")="Invalid, Missing or Expired Refresh Token"
 ;
 ; Use the user identifier in the refresh token to fetch the latest
 ; user claims (which may have changed since the last JWT was created)
 ;
 s id=data("id")
 s claims("username")=$g(^authentication("byId",id,"username"))
 s claims("firstname")=$g(^authentication("byId",id,"firstname"))
 m ^rob("refreshJWT","claims")=claims
 d refreshJWT^RestSecure(id,data("refreshToken"),.claims,.headers)
 d returnAuthToken^RestSecure(.req,.headers)
 s res("ok")="true"
 m res("claims")=claims
 QUIT $$response^%zmgweb(.res,.headers) 
 ;
refreshIdToken(req) ;
 ;
 k ^rob("refreshIdToken") m ^rob("refreshIdToken")=req
 n claims,data,errors,headers,id,ok,options
 ;
 s ok=$$getRefreshToken^RestSecure(.req,.data)
 i 'ok d  QUIT $$errorResponse^%zmgweb(.errors)
 . s errors("error")="Invalid, Missing or Expired Refresh Token"
 ;
 ; Use the user identifier in the refresh token to fetch the latest
 ; user claims (which may have changed since the last JWT was created)
 ;
 s id=data("id")
 s claims("username")=$g(^authentication("byId",id,"username"))
 s claims("firstname")=$g(^authentication("byId",id,"firstname"))
 m ^rob("refreshIdToken","claims")=claims
 d refreshIdToken^RestSecure(id,data("refreshToken"),.headers)
 d returnAuthToken^RestSecure(.req,.headers)
 s res("ok")="true"
 m res("claims")=claims
 QUIT $$response^%zmgweb(.res,.headers) 
 ;
helloworld(req) ;
 k ^rob("helloworld") m ^rob("helloworld")=req
 new claims,errors,headers,res
 ;
 i '$$validJWT^RestSecure(.req,.errors,.claims) QUIT $$errorResponse^%zmgweb(.errors)
 ;
 m ^rob("helloworld","claims")=claims
 s res("username")=$g(claims("username"))
 s res("hello")="world"
 ;
 d returnAuthToken^RestSecure(.req,.headers)
 m ^rob("helloworld","headers")=headers
 QUIT $$response^%zmgweb(.res,.headers)
 ;
 ;i $$updateJWT^RestSecure(.req,.res,.headers,.errors) d  QUIT $$response^%zmgweb(.res,.headers)
 ;s sessionId=$$updateIdToken^RestSecure(.req,.res,.headers,.errors)
 ;s sessionId=123
 ;i sessionId'=""  d  QUIT $$response^%zmgweb(.res,.headers)
 ;. n username
 ;. s ^rob("x","sessionId")=sessionId 
 ;. s username=$$getSessionValue^RestSecure(sessionId,"username")
 ;. s ^rob("x","username")=username 
 ;. s res("hello")=username
 ;e  QUIT $$errorResponse^%zmgweb(.errors)
 ;QUIT
 ;
helloworldToken(req) ;
 k ^rob("helloworldToken") m ^rob("helloworldToken")=req
 new data,errors,headers,id,idToken,refreshToken,res
 ;
 i '$$validIdToken^RestSecure(.req,.errors,.data) QUIT $$errorResponse^%zmgweb(.errors)
 ;
 s id=$g(data("id"))
 s res("firstname")=$g(^authentication("byId",id,"firstname"))
 s res("username")=$g(^authentication("byId",id,"username"))
 s res("hello")="world"
 ;
 s idToken=$g(data("idToken"))
 s refreshToken=$g(data("refreshToken"))
 d updateIdToken^RestSecure(idToken,refreshToken,.headers,.errors)
 d returnAuthToken^RestSecure(.req,.headers)
 m ^rob("helloworldToken","headers")=headers
 QUIT $$response^%zmgweb(.res,.headers)
 ;
login(req) ;
 ;
 k ^rob("login") m ^rob("login")=req
 new claims,errors,headers,id,options,password,res,username
 ;
 s username=$g(req("body","username"))
 i username="" d  QUIT $$errorResponse^%zmgweb(.errors)
 . s errors("error")="Missing Username"
 ;
 s id=$g(^authentication("byUsername",username))
 i id="" d  QUIT $$errorResponse^%zmgweb(.errors)  
 . s errors("error")="Invalid Username"
 ;
 s password=$g(req("body","password"))
 i password="" d  QUIT $$errorResponse^%zmgweb(.errors)
 . s errors("error")="Missing Password"
 ;
 i password'=$g(^authentication("byId",id,"password")) d  QUIT $$errorResponse^%zmgweb(.errors)
 . s errors("error")="Invalid Password"
 ;
 s firstname=$g(^authentication("byId",id,"firstname"))
 s claims("username")=username
 s claims("firstname")=firstname
 s options("jwtExpiryTime")=120
 s options("refreshTokenExpiryTime")=600
 s options("secureCookie")=1
 s options("sameSiteCookie")=1
 d createJWT^RestSecure(1,.claims,.options,.headers)
 d returnAuthToken^RestSecure(.req,.headers)
 s res("ok")="true"
 QUIT $$response^%zmgweb(.res,.headers) 
 ;
loginToken(req) ;
 ;
 ; Login returning session token rather than JWT
 ;
 k ^rob("loginToken") m ^rob("loginToken")=req
 new claims,errors,headers,id,options,password,res,username
 ;
 s username=$g(req("body","username"))
 i username="" d  QUIT $$errorResponse^%zmgweb(.errors)
 . s errors("error")="Missing Username"
 ;
 s id=$g(^authentication("byUsername",username))
 i id="" d  QUIT $$errorResponse^%zmgweb(.errors)  
 . s errors("error")="Invalid Username"
 ;
 s password=$g(req("body","password"))
 i password="" d  QUIT $$errorResponse^%zmgweb(.errors)
 . s errors("error")="Missing Password"
 ;
 i password'=$g(^authentication("byId",id,"password")) d  QUIT $$errorResponse^%zmgweb(.errors)
 . s errors("error")="Invalid Password"
 ;
 s firstname=$g(^authentication("byId",id,"firstname"))
 s claims("username")=username
 s claims("firstname")=firstname
 s options("refreshTokenExpiryTime")=600
 s options("secureCookie")=1
 s options("sameSiteCookie")=1
 d createIdToken^RestSecure(id,.options,.headers) ;
 d returnAuthToken^RestSecure(.req,.headers)
 s res("ok")="true"
 m res("claims")=claims
 QUIT $$response^%zmgweb(.res,.headers) 
 ;
 ;

