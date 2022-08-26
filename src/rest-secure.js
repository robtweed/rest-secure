/*
 ----------------------------------------------------------------------------
 | REST-Secure: Secure REST Browser Interface                                |
 |                                                                           |
 | Copyright (c) 2022 M/Gateway Developments Ltd,                            |
 | Redhill, Surrey UK.                                                       |
 | All rights reserved.                                                      |
 |                                                                           |
 | http://www.mgateway.com                                                   |
 | Email: rtweed@mgateway.com                                                |
 |                                                                           |
 |                                                                           |
 | Licensed under the Apache License, Version 2.0 (the "License");           |
 | you may not use this file except in compliance with the License.          |
 | You may obtain a copy of the License at                                   |
 |                                                                           |
 |     http://www.apache.org/licenses/LICENSE-2.0                            |
 |                                                                           |
 | Unless required by applicable law or agreed to in writing, software       |
 | distributed under the License is distributed on an "AS IS" BASIS,         |
 | WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  |
 | See the License for the specific language governing permissions and       |
 |  limitations under the License.                                           |
 ----------------------------------------------------------------------------

26 August 2022 

 */

  // For source of these handler scripts, see the /idb_handlers folder

let handlerCode = new Map([
  ['instantiate', `
(function () {
  let initialised = false;
  let authorization = false;
  let timeout = 20000; // 20 seconds default fetch timeout

  function isEmpty(obj) {
    for (const key in obj) {
      return false;
    }
    return true;
  }

  function uuidv4(protocol) {
    if (protocol === 'https:') {
      return ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
        (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
      );
    }
    else {
      return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        let r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
      });
    }
  }

  function jwt_decode(jwt) {

    // Adapted from Auth0: https://github.com/auth0/jwt-decode

    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

    function InvalidCharacterError(message) {
      this.message = message;
    }

    InvalidCharacterError.prototype = new Error();
    InvalidCharacterError.prototype.name = "InvalidCharacterError";

    function b64DecodeUnicode(str) {
      return decodeURIComponent(
        atob(str).replace(/(.)/g, function(m, p) {
          var code = p.charCodeAt(0).toString(16).toUpperCase();
          if (code.length < 2) {
            code = "0" + code;
          }
          return "%" + code;
        })
      );
    }

    function base64_url_decode(str) {
      var output = str.replace(/-/g, "+").replace(/_/g, "/");
      switch (output.length % 4) {
        case 0:
          break;
        case 2:
          output += "==";
          break;
        case 3:
          output += "=";
          break;
        default:
          throw "Illegal base64url string!";
      }

      try {
        return b64DecodeUnicode(output);
      }
      catch (err) {
        return atob(output);
      }
    }

    function InvalidTokenError(message) {
      this.message = message;
    }

    InvalidTokenError.prototype = new Error();
    InvalidTokenError.prototype.name = "InvalidTokenError";

    function jwtDecode(token, options) {
      if (typeof token !== "string") {
        throw new InvalidTokenError("Invalid token specified");
      }
      options = options || {};
      var pos = options.header === true ? 0 : 1;
      try {
        return JSON.parse(base64_url_decode(token.split(".")[pos]));
      }
      catch (e) {
        throw new InvalidTokenError("Invalid token specified: " + e.message);
      }
    }

    return jwtDecode(jwt);
  }

  self.handler = async function(obj, finished) {

    // obj.endpoint
    // obj.protocol
    // obj.contentType
    // obj.useXAuth (true | false)
    // obj.responseHandlerUrl (optional)
    // obj.authTokenType (Bearer is default, or Token, empty string)
    // obj.refresh_token_uri
    // obj.timeout
    // obj.authHeader.request
    // obj.authHeader.response

    let worker = this;

    let loadRestResources = obj.load_rest_resources || false;
    let responseHandlerUrl = obj.responseHandlerUrl;
    let authTokenType = obj.authTokenType || 'Bearer ';
    if (authTokenType !== '' && authTokenType.slice(-1) !== ' ') authTokenType= authTokenType + ' ';
    let useJWT = obj.useJWT || false;
    let refresh_token_uri = obj.refresh_token_uri;
    let authHeader = obj.authHeader;
    if (!authHeader) authHeader = {};
    if (!authHeader.request) authHeader.request = 'Authorization';
    if (!authHeader.response) authHeader.response = 'authorization';

    if (obj.timeout) timeout = obj.timeout;
    let defaultTimeout = timeout;

    if (initialised) {
      return finished({
        error: 'QOper8 WebWorker has already been initiated'
      });
    }

    self.restSecure = {};

    self.restSecure.isInitialised = function() {
      return initialised;
    };

    let useXAuth = obj.useXAuth;

    if (typeof obj.endpoint === 'undefined') {
      return finished({
        error: 'No endpoint provided'
      });
    }

    let token = uuidv4();
    let endpoint = obj.endpoint;
    let contentType = obj.contentType || 'application/json';
    let jwt;

    let rest_resources = obj.rest_resources || {};
  
    self.restSecure.isValidToken = function(token_input) {
      return token_input === token;
    };

    self.restSecure.fetch = async function(opt) {

      const abortController = new AbortController();
      const abortTimer = setTimeout(function() {
        abortController.abort();
      }, timeout);

      // if the authorization token is a JWT, check to see if it's expired
      //  if it has, then request a new JWT using the refresh token (which is in the secure cookie)

      if (refresh_token_uri && jwt && jwt.exp < (Date.now()/1000)) {

        // fetch a new JWT using the refresh token

        let resource = endpoint + refresh_token_uri;
        let options = {
          method: 'GET',
          headers: {
            'Content-type': 'application/json'
          },
          signal: abortController.signal
        };

        try {
          let res = await fetch(resource, options);
          clearTimeout(abortTimer);
          let auth = res.headers.get(authHeader.response);
          if (auth && auth !== '') authorization = auth;

          // reset the fetch abort timer

          abortTimer = setTimeout(function() {
            abortController.abort()
          }, timeout);
        }
        catch(err) {
          // reduce the timeout for subsequent requests
          timeout = 1000;

          setTimeout(function() {
            // restore default timeout in 5 minutes time
            timeout = defaultTimeout;
          }, 300000);
        }
      }

      if (!opt.headers) opt.headers = {};
      let cType = opt.headers.contentType || contentType;

      if (cType === 'application/json' && typeof opt.body === 'object') {
        opt.body = JSON.stringify(opt.body);
      }

      let resource = endpoint + opt.uri;

      let restToken = uuidv4();
      let options = {
        method: opt.method,
        body: opt.body,
        headers: {
          'Content-type': cType,
          'X-Authorization': 'Bearer ' + restToken
        },
        signal: abortController.signal
      };

      if (opt.headers) {
        for (const name in opt.headers) {
          let namelc = name.toLowerCase();
          if (!['content-type', 'x-authorization', 'authorization'].includes(namelc)) {
            options.headers[name] = opt.headers[name];
          }
        }
      }

      if (authorization) {
        options.headers[authHeader.request] = authTokenType + authorization;
      }

      // **** Do the actual fetch now *****

      let response;
      try {
        response = await fetch(resource, options);
        clearTimeout(abortTimer);
      }
      catch(err) {
        timeout = 1000;

        setTimeout(function() {
          // restore default timeout in 5 minutes time
          timeout = defaultTimeout;
        }, 300000);

        return {
          body: {
            error: 'Request timed out'
          }
        };
      }

      let headers = {};
      for (const [key, value] of response.headers.entries()) {
        headers[key] = value;
      }
      if (useXAuth) {
        let returnedToken = response.headers.get('x-request-id');
        if (restToken !== returnedToken) {
          return {error: 'Unable to match x-authorization token'};
        }
      }
      if (cType === 'application/json') {
        response = await response.json();
      }

      if (opt.responseHandlerUrl) {
        importScripts(opt.responseHandlerUrl);
        if (self.responseHandler) {
          let resObj = self.responseHandler(response, headers);
          response = resObj.response;
          headers = resObj.headers;
        }
      }

      if (headers[authHeader.response]) {
        authorization = headers[authHeader.response];
        delete headers[authHeader.response];

        // is this a JWT?

        try {
          jwt = jwt_decode(authorization);
          if (opt.jwt_claims) {
            opt.jwt_claims.forEach(function(claim) {
              response[claim] = jwt[claim];
            });
          }
        }
        catch(err) {
        }
      }

      return {
        body: response,
        headers: headers
      };
    };

    let already_authenticated = false;
    let claims;
    if (refresh_token_uri) {

      // when starting up for the first time, see if there's a valid
      // refresh token in the browser's secure cookie.  If so, fetch and
      // save a fresh JWT or idToken


      let res = await self.restSecure.fetch({
        uri: refresh_token_uri
      });

      claims = res.body && res.body.claims;

      if (authorization) already_authenticated = true;
    }

    initialised = true;
    finished({
      already_authenticated: already_authenticated,
      claims: claims,
      qoper8: {
        token: token
      }
    });
  };
})();

  `],

  ['secure_fetch', `
  self.handler = async function(obj, finished) {
    let worker = this;

    if (!self.restSecure || !self.restSecure.isInitialised()) {
      return finished({
        error: 'REST-Secure QOper8 WebWorker has not been initialised'
      });
    }

    if (!self.restSecure.isValidToken(obj.qoper8.token)) {
      return finished({
        error: 'Invalid token received from main process'
      });
    }

    let options = obj.options;

    let res = await self.restSecure.fetch({
      uri: obj.uri,
      method: options.method,
      body: options.body,
      headers: options.headers,
      responseHandlerUrl: options.responseHandlerUrl,
      jwt_claims: options.jwt_claims
    });

    if (res.headers) delete res.headers['x-request-id'];
    finished(res);
  };
  `]

]);

// *****  REST-Secure ********

let REST_Secure = class {
  constructor(options) {
    let QOper8 = options.QOper8;
    let qOptions = options.qOptions || {};

    this.name = 'REST-Secure';
    this.build = '0.1';
    this.buildDate = '26 August 2022';

    let qoper8 = new QOper8({
      poolSize: 1,
      logging: qOptions.logging,
      workerInactivityCheckInterval: qOptions.workerInactivityCheckInterval || 60,
      workerInactivityLimit: qOptions.workerInactivityLimit || 60
    });

    for (const [key, value] of handlerCode) {
      qoper8.handlersByMessageType.set(key, qoper8.createUrl(value));
    }

    let rs = this;

    this.start = async function() {

      let msg = {
        type: 'instantiate',
        contentType: options.contentType,
        protocol: window.location.protocol,
        endpoint: options.endpoint,
        authTokenType: options.authTokenType,
        refresh_token_uri: options.refresh_token_uri,
        timeout: options.timeout,
        authHeader: options.authHeader
      };

      let res = await qoper8.send(msg);

      if (res.error) {
        return res;
      }

      let already_authenticated = res.already_authenticated;
      let claims = res.claims;

      async function secure_fetch(uri, options) {

        let msg = {
          type: 'secure_fetch',
          uri: uri,
          options: options,
          qoper8: {
            token: res.qoper8.token
          }
        }
        return new Promise((resolve) => {
          qoper8.message(msg, function(responseObj) {
            resolve(responseObj);
          });
        });
      }

      rs.fetch = async function(uri, options) {
        options = options || {};
        if (options.responseHandlerCode) {
          options.responseHandlerUrl = qoper8.createUrl(options.responseHandlerCode);
        }
        let resp = await secure_fetch(uri, options);
        delete resp.qoper8;
        return resp;
      };

      return {
        already_authenticated: already_authenticated,
        claims: claims
      };
    }
  }
};

export {REST_Secure};


