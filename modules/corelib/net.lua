function translateNetworkError(errcode, connecting, errdesc)
  local text
  if errcode == 111 then
    text = tr('Connection refused.\nThe server might be offline or restarting.\nPlease try again later.')
  elseif errcode == 110 then
    text = tr('Connection timed out.\nEither your network is failing or the server is offline.')
  elseif errcode == 1 then
    text = tr('Connection failed.\nThe server address does not exist or could not be resolved.')
  elseif connecting then
    text = tr('For some reason you are unable to log in,\ncheck your internet connection and make sure the\nserver is online. If the server is online and your\ninternet connection is normal, we suggest\nre-downloading the client to remedy the problem.')
  else
    text = tr('Your connection has been lost.\nEither your network or the server went down.')
  end
  return text
end
