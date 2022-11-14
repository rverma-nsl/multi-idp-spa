import { Typography } from "@ory/elements"
import { useEffect, useState } from "react"
// import Iframe from 'react-iframe'
import axios from "axios";
import jwt_decode from "jwt-decode";

export const Cdui = () => {
  const [user, setUser] = useState([]);
  let config = {
    headers: {
      'Content-type': 'application/x-www-form-urlencoded',
    }
  }
  useEffect(() => {
    axios.post('http://localhost:8080/realms/master/protocol/openid-connect/token')
      .then(res => {
        const token = res.data.token;
        // localStorage.setItem('nsl_token', token);
        setUser(jwt_decode(token))
        // dispatch(actions.authSuccess(token, user));
      })
      .catch(err => {
        console.log(err)
        // dispatch(actions.loginUserFail());
      });
  }, []);
  return (
    <>
      <Typography size={"headline37"}>Api Response of CDUI Posts</Typography>
      <pre>
      <code>{JSON.stringify(user, null, 2)}</code>
    </pre>
      {/* <Iframe url="http://grafana.test.info/d-solo/TXSTREZ/simple-streaming-example?orgId=1&from=1668321779413&to=1668321839413&panelId=4"
        width="1050px"
        height="800px"
        id=""
        className=""
        display="block"
        position="relative" /> */}
    </>
  );
}