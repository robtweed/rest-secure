# Rest-Secure: Secure Rest Interface using a WebWorker
 
Rob Tweed <rtweed@mgateway.com>  
25 May 2023, MGateway Ltd [https://www.mgateway.com](https://www.mgateway.com)  

Twitter: @rtweed

Google Group for discussions, support, advice etc: [http://groups.google.co.uk/group/enterprise-web-developer-community](http://groups.google.co.uk/group/enterprise-web-developer-community)


## What is Rest-Secure?

WebWorkers provide an interesting opportunity for the creation of a much more secure REST interface for browsers.  This is particularly important for the security and protection of a back-end system that is accessed via REST: it needs to be sure that the client requesting access to potentially sensitive information can be trusted and is who it claim to be.

Typically this is currently achieved using authorization credentials such as randomised session tokens and/or JSON Web Tokens (JWT), but these can still potentially be hijacked and used, for example by malicious third-party scripts within a browser by exploiting security weaknesses within an application's code.

WebWorkers can be used to create a separate thread of execution within the browser that is accessible from the main browser process by a tightly-restricted API, and within which the run-time environment and its local variables are otherwise inaccessible from the main browser process.  If external REST access is implemented within such a WebWorker, the authorization credentials shared between the browser and back-end system can reside solely and securely within the WebWorker, and can therefore be inaccessible to the main browser process.

Furthermore, if a single WebWorker is maintained by our [QOper8](https://github.com/robtweed/QOper8) module, then its tightly-controlled queue-based architecture means that communication between the browser and back-end REST system can be restricted to a single channel of request and responses that take place in strict chronological order.  This can be very beneficial for the back-end system: it cannot then be bombarded by multiple, parallel requests from a browser which (a) places extra load on the back-end system and (b) can be difficult for a back-end system to handle if such requests need handling in a particular order to prevent race conditions etc. 

There's a further potential advantage: if the back-end knows that the client is limited to sending a single request at a time, then it could add a further level of security by sending a new, randomly-generated access token with each response it returns to the browser, and then expect to receive that token with the next request from the client.  With such a regime, a malicious attempt to access the back-end by bypassing the WebWorker interface would be unable to provide that randomly-generated single-use access token and therefore such attempts could easily be identified and rejected by the back-end.

Rest-Secure pulls together a QOper8-based WebWorker and a secure environment with that WebWorker within which the standard *fetch()* API is used for external REST communication and authentication credentials are held in memory.  

Rest-Secure exposes a single API within the main browser process - *rest-secure.fetch()* - which emulates the standard *fetch()* API and acts as a proxy to the real thing running within the secure environment provided by the WebWorker.


## Will Rest-Secure Work on All Browsers?

QOper8 should work on all modern browsers. The key dependencies are that the browser must support:

- WebWorkers
- async/await
- ES6 Modules
- the Fetch() API


## Installing

### From CDN

You can use Rest-Secure directly from the Github CDN linked to this repository.  In your main module, load it using:

      const {Rest_Secure} = await import('https://cdn.jsdelivr.net/gh/robtweed/rest-secure/src/rest-secure.js');

You must also ensure that QOper8 is imported:

      const {QOper8} = await import('https://cdn.jsdelivr.net/gh/robtweed/QOper8/src/qoper8.min.js');

### Clone from Github

Alternatively, clone or copy the file [*/src/rest-secure.js*](/src/rest-secure.js)
to an appropriate directory on your web server and load it directly from there, eg:


      const {Rest_Secure} = await import('/path/to/rest-secure.js');

You must also [clone or copy QOper8 from its repository](https://github.com/robtweed/QOper8#clone-from-github)

### From NPM

        npm install rest-secure

Then you can import the Rest_Secure and QOper8 classes:

        import {Rest_Secure} from 'rest-secure';
        import {QOper8} from 'qoper8-ww';


NPM automatically imports QOper8 as a dependency of Rest-Secure.


## Instantiating Rest-Secure


Create an instance of the *Rest_Secure* class, eg:

      let rest_secure = new REST_Secure({
        QOper8: QOper8,
        endpoint: 'https://www.example.com/rest-secure-app'
      });


Note that, as a minimum, you must provide Rest_Secure with:

- your imported instance of QOper8
- the REST endpoint to which each of your application's specific REST APIs (eg */api/login*) will be appended


## Starting Rest-Secure

In order to make use of Rest-Secure's proxied *fetch()* API, you must start it:


      let status = await rest_secure.start();

In the unlikely event of this failing, you can check for any errors, eg:

      if (status.error) {
        console.log(status.error)
        return;
      }

Rest-Secure is now ready for use.  If you take a look using the browser's Developer Tools, you'll see that a WebWorker is now running.


## Using Rest-Secure

You send a request using the api:

      let res = await rest_secure.fetch(resource, options);

The *fetch()* interface is identical to the browser's standard *fetch()* API.  Everything you specify will be passed through to the actual *fetch()* API that executes within the WebWorker.

The main difference is in the response.  If the outgoing request had a MIME type of *application/json*, then the response body will have already been parsed for you.  Additionally the headers will be mapped to a simple object.

The *res* response object will have the format:

      {
        body: {
          // parsed body values
        },
        headers: {
          // parsed HTTP response headers
        }
      }

For example:

      {
        "body": {
          "firstname": "Rob",
          "hello": "world",
          "username": "rtweed"
        },
        "headers": {
          "content-length": "55",
          "content-type": "application/json",
          "date": "Thu, 25 Aug 2022 14:43:48 GMT",
          "server": "nginx/1.23.0"
        }
      }

Note: Any *authorization* response header (eg a token or JWT) returned by the back-end REST system is very deliberately **not** forwarded to the main browser process.  Instead it is retained within the Rest-Secure WebWorker and automatically added to the next outgoing request as a Bearer Token on the *Authorization* Request Header.  The only way you'll be able to inspect this *Authorization* header value is by using the browser's Developer Tools and inspecting the incoming responses and outgoing requests.  You cannot directly access or modify it.


Error responses have the format:

      {
        body: {
          error: 'Error text'
        }
      }



## Using JWTs and Refresh Tokens with Rest-Secure

If the back-end REST systems uses JWTs for user authorization, then it is recommended that they are short-lived (eg with an *exp* claim of, say, 300 seconds).  If/when they expire, they should be refreshed using a long-lived Refresh Token which should have been sent to the browser along with the original JWT using a *Set-Cookie* response header.  This cookie should be specified as an HTTP-Only Cookie with a *Max-Age* property that defines its expiry time.  It is further recommended that, if possible, this cookie is also specified as *Secure* and *Same-Site* to further mitigate any malicious attempts to access it.

The creation of the initial JWT and its accompanying Refresh Token cookie are, of course, the responsibility of the back-end REST system.  Rest-Secure also plays no role in the Refresh Token cookie being saved in the browser, but, as noted in the previous section, Rest-Secure will extract and retain the value specified in the *authorization* response header, which is where a JWT will be expected.  Rest-Secure will automatically determine if this *authorization* token is a JWT or just a simple random string token.

If a Refresh Token cookie has been created, then, of course, it will be automatically sent to the back-end system with every subsequent outgoing request from the WebWorker.  The back-end system can determine if or how it needs to use it with each request it receives, but normally it would not be expected to be actively used by the back-end.

You can optionally instruct Rest-Secure to become actively involved in the use of the Refresh Token to request an updated JWT from the Rest Server.  This mechanism requires and expects the REST server to provide a specific URI for such JWT Refresh requests, eg:

      GET /api/refresh_token

To activate this mechanism, add this URI to the *Rest_Secure* class constructor, eg:


      let rest_secure = new REST_Secure({
        QOper8: QOper8,
        endpoint: 'https://www.example.com/rest-secure-app',
        refresh_token_uri: '/api/refresh_token'
      });


Rest-Secure will now do a couple of interesting things automatically:

- When you invoke Rest-Secure's *start()* API, it will send a Refresh Token request to the REST server, on the basis that there might be a valid unexpired Refresh Token cookie in the browser:

  - if so, this will be sent along with the GET request to the REST Server, and, after due validation of the received cookie, it can return a fresh JWT to the client in its response's *authorization* header, which Rest-Secure will extract and retain in its WebWorker.

  - if not, then no *authorization* header value will be returned by the Rest Server to Rest-Secure's WebWorker.

  The status value returned by Rest-Secure's *start()* API will tell you which outcome occurred, via a property named *already_authenticated* which will be either *true* or *false*:


      let status = await rest_secure.start();

      if (!status.already_authenticated) {
        // You'll need to prompt the user to login and send a login request
      }
      else {
        // the Refresh Token cookie must have been valid and the REST server returned a fresh JWT
      }


- Whenever the Rest-Secure WebWorker is about to invoke the *fetch()* API to send a REST Request, it will check whether or not the JWT has expired (using its standard *exp* claim).  If it has expired, then Rest-Secure will send a Refresh Token request to the REST Server.  If it returns a new JWT, then this will be applied to the pending REST Request (and all subsequent requests until it expires).  

  If the REST Server did not return a JWT (via the *authorization* response header), then the pending REST request will be sent anyway with the expired JWT, on the basis that the REST Server will then reject the request and return its appropriate error response.  This error will be returned to the awaiting *fetch()* Promise in the main browser thread and it is then up to you to handle it appropriately.


## Authentication using JWTs

If the REST Server uses JWTs, it will usually return one to Rest-Secure on successful authentication, eg via a REST API such as */api/login* that included credentials such as a username and password.

Although the JWT will remain within Rest-Secure's WebWorker, and therefore inaccessible to the main browser process, you may wish to obtain some or all of its Custom Claims and have them returned to the main browser process.

Rest-Secure allows you to do this by adding a special option - *jwt_claims* - to the *rest-secure.fetch()* API.  This allows you to specify, in an array, the names of the JWT Custom Claims you want to return in the response.  For example: 


      let res = await rest_secure.fetch('/api/login',{
        method: 'POST',
        body: {
          username: 'xxxxxxx',
          password: 'yyyyyyyy'
        },
        jwt_claims: ['username', 'firstname']
      });

On successful login, the value of *res* will include the values of these JWT claims in its body, eg:

      {
        body: {
          username: 'xxxxxxx',
          firstName: 'Rob'
        }
      }
      

Note that the Claim Names are case-sensitive.


For security reasons, Rest-Secure does not provide any other means of extracting or accessing JWT Claim values.


## Using Simple Authorization and Refresh Tokens with Rest-Secure

Rest-Secure does not mandate or assume the use of JWTs as authorization tokens, but it will automatically detect if they are being used.

The back-end REST server may, instead, use a simple randomly-generated token (eg a UUID) that it generates and uses as both an authorization and session token.  

If such a simple token is returned by the REST Server in the *authorization* response header, then Rest-Secure will extract it and add it to the next outgoing REST request (as a Bearer Token in the Authorization request header).  Such a token has no meaning or other use to Rest-Secure.

Because Rest-Secure uses QOper8 with a single WebWorker, all requests generated in the main browser process are queued and sent in strict chronological order, one at a time, to the REST Server.  A queued request will not be sent until Rest-Secure's WebWorker has received and completed handling of the response to the previous request.

This can be used by the REST Server to apply a further level of security, by always sending a new authorization token with each response, thereby making the authorization tokens single-use and impossible to forge or anticipate.  Of course, such a regime is for the REST Server to implement: Rest-Secure's role is to passively return the previously-sent token with the next outgoing request.

### Using Refresh Tokens with Simple Authorization Tokens

The Rest Server may also combine such tokens with a long-lived Refresh Token that it sends on successful authentication as an HTTP-Only Cookie using the Set-Cookie response header.  If so, this cookie should specify a *Max-Age* property that defines its expiry time.  It is further recommended that, if possible, this cookie is also specified as *Secure* and *Same-Site* to further mitigate any malicious attempts to access it.

You can instruct Rest-Secure to use Refresh Tokens in the same way as they are used with JWTs.  This mechanism requires and expects the REST server to provide a specific URI for such Token Refresh requests, eg:

      GET /api/refresh_token

To activate this mechanism, add this URI to the *Rest_Secure* class constructor, eg:


      let rest_secure = new REST_Secure({
        QOper8: QOper8,
        endpoint: 'https://www.example.com/rest-secure-app',
        refresh_token_uri: '/api/refresh_token'
      });


When you invoke Rest-Secure's *start()* API, it will send a Refresh Token request to the REST server, on the basis that there might be a valid unexpired Refresh Token cookie in the browser:

- if so, this will be sent along with the GET request to the REST Server, and, after due validation of the received cookie, it can return a fresh authorization token to the client in its response's *authorization* header, which Rest-Secure will extract and retain in its WebWorker.

- if not, then no *authorization* header value will be returned by the Rest Server to Rest-Secure's WebWorker.

  The status value returned by Rest-Secure's *start()* API will tell you which outcome occurred, via a property named *already_authenticated* which will be either *true* or *false*:


      let status = await rest_secure.start();

      if (!status.already_authenticated) {
        // You'll need to prompt the user to login and send a login request
      }
      else {
        // the Refresh Token cookie must have been valid and the REST server returned a fresh token
      }

Note that as simple authorization tokens have no inherent expiry time defined, Rest-Secure does not otherwise send any other Refresh Token requests at any time.  It is up to the back-end REST Server to determine the validity of the returned authorization tokens that it receives from Rest-Secure.


## Applying a Timeout to Rest-Secure's Proxied Fetch Requests

Because Rest-Secure uses a single WebWorker and QOper8 queues all REST requests generated in the main browser process, it is important to avoid a situation where the back-end REST server fails to respond and therefore the application stalls.

By default, Rest-Secure applied a 20 second timeout to all of its *fetch()* requests.  You can change this value when you first instantiate Rest-Secure by specifying a *timeout* value in milliseconds, eg to set a 5 second timeout:

      let rest_secure = new REST_Secure({
        QOper8: QOper8,
        endpoint: 'https://www.example.com/rest-secure-app',
        timeout: 5000
      });


### What Happens if the Timeout is Exceeded?

If the timeout is exceeded, Rest-Secure will return an error response to the awaiting *rest-secure.fetch()* Promise in the main browser process.  

Furthermore, as there may be other queued requests, and as it would now appear that the REST Server is likely having problems, Rest-Secure now automatically reduces the timeout to 1 second.  This should allow any queued backlog of requests to be cleared fairly quickly if the REST Server remains unavailable.

After 5 minutes, Rest-Secure will return the timeout back to the original value and the process repeats.


## Specifying a Default Content Type

By default, Rest-Secure assumes that all REST APIs will be of type *application/json*, and therefore automatically parses the requests and responses accordingly.

You can change this by specifying the default type when instantiating Rest-Secure, eg:

      let rest_secure = new REST_Secure({
        QOper8: QOper8,
        endpoint: 'https://www.example.com/rest-secure-app',
        content-type: 'application/octet-stream'
      });


Note that if you specify a particular MIME type in a *rest-secure.fetch()* API option, then this will take precedent.


## Specifying Custom Authorization Headers

By default, Rest-Secure will expect authorization tokens or JWTs to be received in the *authorization* HTTP Response Header, and will return authorization tokens to the Rest Server in the *Authorization* HTTP Request Header.

You can change the headers used by Rest-Secure by specifying them in the *authHeader* property when instantiating Rest-Secure.  This property is an object with *request* and *response* keys eg:


      let rest_secure = new REST_Secure({
        QOper8: QOper8,
        endpoint: 'https://www.example.com/rest-secure-app',
        authHeader: {
          request: 'X-Custom-Authorization',
          response: 'x-custom-authorization'
        }
      });



## License

 Copyright (c) 2023 MGateway Ltd,                           
 Redhill, Surrey UK.                                                      
 All rights reserved.                                                     
                                                                           
  https://www.mgateway.com                                                  
  Email: rtweed@mgateway.com                                               
                                                                           
                                                                           
  Licensed under the Apache License, Version 2.0 (the "License");          
  you may not use this file except in compliance with the License.         
  You may obtain a copy of the License at                                  
                                                                           
      http://www.apache.org/licenses/LICENSE-2.0                           
                                                                           
  Unless required by applicable law or agreed to in writing, software      
  distributed under the License is distributed on an "AS IS" BASIS,        
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
  See the License for the specific language governing permissions and      
   limitations under the License.      



