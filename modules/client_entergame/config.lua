--[[
  *Sistema de multi-world, by Mirto (milton33b@hotmail.com)
  *Reduzido a UM mundo: a tela de login nao tem mais escolha de mundo, todo
  *mundo entra no mesmo lugar. Esta e' a unica entrada que o client usa - troque
  *o nome e a porta aqui quando precisar.

    txt  = nome do mundo (aparece nos logs e nos servidores salvos)
    port = porta do servidor de login (obrigatoria; 0 ou ausente = nao entra)
    host = opcional: fixa o host, ignorando o que estiver salvo ou no mod
           (ex.: host = "127.0.0.1" para testar no local)
]]--
servers = {
  {txt = "Raava", port = 9191}
}
