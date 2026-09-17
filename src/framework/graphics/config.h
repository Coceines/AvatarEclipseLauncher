// CRIADO POR SIRIUS, CASO VOCÊ NAO TENHA ADIQUIRIDO COMIGO, ME FALE ATRAVES DO DISCORD __KENAI__
// OBRIGADO POR USAR O MEU SCALER!

#ifndef XBRZ_CONFIG_HEADER_284578425345
#define XBRZ_CONFIG_HEADER_284578425345

//nao inclua nenhum header aqui! usado pelo xBRZ_dll!!!

namespace xbrz
{
struct ScalerCfg
{
    double luminanceWeight            = 1;
    double equalColorTolerance        = 30;
    double dominantDirectionThreshold = 3.6;
    double steepDirectionThreshold    = 2.2;
    double newTestAttribute           = 0; //unused; test new parameters
};
}

#endif

