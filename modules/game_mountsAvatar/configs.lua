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
        {id = "lion", icone = 1, desc = "Lion"},
        {id = "tiger", icone = 2, desc = "Tiger"},
        {id = "dragonlord", icone = 3, desc = "Dragon Lord"}
    },

    [2] = {
 
        {id = "winterwolf", icone = 1, desc = "Winter Wolf"},
        {id = "polarbear", icone = 2, desc = "Polar Bear"},
        {id = "crystalspider", icone = 3, desc = "Crystal Spider"}
    },

 
    [3] = {
        {id = "panda", icone = 1, desc = "Panda"},
        {id = "tilehorned", icone = 2, desc = "Tilehorned"},
        {id = "ancientscarab", icone = 3, desc = "Ancient Scarab"}
    },


    [4] = {
        {id = "bear", icone = 1, desc = "Bear"},
        {id = "warwolf", icone = 2, desc = "War Wolf"},
        {id = "giantspider", icone = 3, desc = "Giant Spider"}
    }
}