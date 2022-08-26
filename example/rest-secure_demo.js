(async () => {

  const {Rest_Secure} = await import('https://cdn.jsdelivr.net/gh/robtweed/rest-secure/src/rest-secure.js');
  const {QOper8} = await import('https://cdn.jsdelivr.net/gh/robtweed/QOper8/src/qoper8.min.js');

  let rest_secure = new REST_Secure({
    QOper8: QOper8,
    timeout: 10000,
    endpoint: 'https://www.example.com/rest-secure',
    refresh_token_uri: '/api/refresh_token'
  });

  let status = await rest_secure.start();

  if (status.error) {
    console.log(status.error)
    return;
  }


  if (!status.already_authenticated) {

    let res = await rest_secure.fetch('/api/login',{
      method: 'POST',
      body: {
        username: 'xxxxxxx',
        password: 'yyyyyyy'
      },
      jwt_claims: ['username', 'firstname']
    });

    console.log('**** res ****');
    console.log(JSON.stringify(res, null, 2));

    if (res.body.error) {
      console.log("Error!: " + res.body.error);
      return;
    }

    console.log('**** logged in response: *****')
    console.log(JSON.stringify(res, null, 2));
  }


  let res = await rest_secure.fetch('/api/helloworld');

  console.log(JSON.stringify(res, null, 2));

  setTimeout(async function() {
    let res = await rest_secure.fetch('/api/helloworld');
    console.log(JSON.stringify(res, null, 2));
  }, 3000);

  setTimeout(async function() {
    let res = await rest_secure.fetch('/api/helloworld');
    console.log(JSON.stringify(res, null, 2));
  }, 10000);

  setTimeout(async function() {
    let res = await rest_secure.fetch('/api/helloworld');
    console.log(JSON.stringify(res, null, 2));
  }, 130000);

})();
