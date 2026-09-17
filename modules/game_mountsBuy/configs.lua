--[[
    Pré-Requisitos (Cliente Side - Servidor envia as informações previamente.)
     1. Ser premium account;
     2. Ter alguma montaria habilitada (comprada, adquirida, conquistada);

    Fluxo Normal
     1. Player clica com o botão direito no personagem;
     2. Player seleciona a opção "mount";
     3. Abre a janela com as opções, motando com o sexoId no final do ID;
     4. Envia para o servidor através de string (talkaction - !mount id), server side faz as checagens;

    Fluxo Alternativo
     2.1 Player já está com a montaria no momento do click;
     2.2 Envia para o servidor através de string (talkaction - !mount none), server side faz as checagens, e desabilita o mount;
     2.3 Volta ao fluxo normal passo 3;
     2.4 Fim.

     4.1 Servidor não aceita o tipo de montaria, por algum motivo server side;
     4.2 Fim.

    DataTable
     1. Dividida por vocId, descrição, ID..sexo será usado pelo server side para identificar a montaria;
     2. Icone será a imagem que representará a montaria, cliente motará TODAS (caso não esteja habilitada, mensagem em rosa).

    Observações
     1. Cada montaria terá sua baseSpeed calculada server side;
     2. Cliente não será informado se o player está ou não de montaria, apenas executará o(s) comando(s).
]]--

pastas = {"fire", "water", "air", "earth"}

mountsData = { 
    [1] = {
        {id = 1, desc = "Nethersteed"},
        {id = 2, desc = "Draptor"},
        {id = 3, desc = "Magma Crawler"},
        {id = 4, desc = "Fire Panther"},
        {id = 5, desc = "Armoured War Horse"},
        {id = 6, desc = "Blackpelt"},
        {id = 7, desc = "Blazebringer"},
        {id = 8, desc = "Doombringer"}
    },

    [2] = {
 
        {id = 1, desc = "Crystal Wolf"},
        {id = 2, desc = "Manta Ray"},
        {id = 3, desc = "Coralripper"},
        {id = 4, desc = "Titanica"},
        {id = 5, desc = "Ursagrodon"},
        {id = 6, desc = "Jade Pincer"},
        {id = 7, desc = "Flitterkatzen"},
        {id = 8, desc = "Jade Lion"}
    },

 
    [3] = {
        {id = 1, desc = "Waccoon"},
        {id = 2, desc = "Iron Blight"},
        {id = 3, desc = "Kingly Deer"},
        {id = 4, desc = "Noble Lion"},
        {id = 5, desc = "Panda"},
        {id = 6, desc = "Highland Yak"},
        {id = 7, desc = "Slagsnare"},
        {id = 8, desc = "Racing Bird"}
    },


    [4] = {
        {id = 1, desc = "Gorongra"},
        {id = 2, desc = "Stampor"},
        {id = 3, desc = "Carpacosaurus"},
        {id = 4, desc = "Shock Head"},
        {id = 5, desc = "Scorpion King"},
        {id = 6, desc = "Tiger Slug"},
        {id = 7, desc = "Widow Queen"},
        {id = 8, desc = "Dromedary"}
    }
}