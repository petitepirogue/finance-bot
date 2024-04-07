//+------------------------------------------------------------------+
//|                                                BotBotLiberty.mq5 |
//|                                        Copyright 2024, GenixCode |
//|                                        https://www.genixcode.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, GenixCode"
#property link "https://www.genixcode.com"
#property version "1.00"

// inportation des modules
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Paramètre d'entrée du robot                                      |
//+------------------------------------------------------------------+
input double stopLossPercentage = 3.0;            // risque de perte en % accepté
input double takeProfitPercentage = 10.0;         // risque de perte si nous sommes en profit & que nous avons atteint le targetProfit
input double targetProfit = 100.0;                // objectif maximal de gain
input int numberBot = 20230406;                   // le nombre pour identifier le bot
input string analyseTechnique = "moyenne_mobile"; // choix de l'analyse technique
input int mmSept = 7;                             // Moyenne mobile MM7
input int mmVingt = 20;                           // Moyenne mobile MM20
input int mmCinquante = 50;                       // Moyenne mobile MM50
input int mmDeuxCent = 200;                       // Moyenne mobile MM200
input double lotSize = 0.2;
input int limitTradeByDay = 20;    // limite du nombre d'entrée au trade
input int limitLostTradeByDay = 5; // limit de perte de trade par jour si le stoplost est touche
input int sessionTradeMax = 2;
input int daysNotTrade = 20230406;        // lsite des jours à ne pas trader
input int betwenTimesNotTrade = 20230406; // liste des heures à ne pas trader si dans le marche sortir

//+------------------------------------------------------------------+
//| Création des variables du robots                                 |
//+------------------------------------------------------------------+
#define EXPERT_MAGIC numberBot; // utilisation de la technique de tradosaure

CTrade TradeManager;     // objet pour la gestion du trade
double gains = 0;        // gain ou perte de la session en cours
int countStopLost = 0;   // nombre maximal de perte dans la journee
int countLimitTrade = 0; // nombre maximal de trade dans la journee
double positionY = 0;
int currentTypeTrade = 0;

//+------------------------------------------------------------------+
//| Expert initialization function lors de la modification du système|
//| temps, indicateurs & vars du marche ou ajout d'un event                              |
//+------------------------------------------------------------------+
int OnInit()
{
    //---

    //---
    return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //---
}
//+------------------------------------------------------------------+
//| Expert tick function  pour chaque nouvelle bougie                |
//+------------------------------------------------------------------+
void OnTick()
{
    valYCrossingMM(mmSept, mmVingt);
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
    //---
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Moyenne Mobile                                                   |
//+------------------------------------------------------------------+
// verification ex. si la MM7 & MM20 se croise
// et je retourne la valeur des axes des oronnees y
// Déclaration de l'énumération ENUM_MA_METHOD pour MODE_SMA
int valYCrossingMM(int mm7 = 7, int mm20 = 20)
{

    double myMovingAverrageArray1[], myMovingAverrageArray2[];

    int mm7_value = iMA(NULL, 0, mm7, 0, MODE_SMA, PRICE_CLOSE);   // Valeur de la moyenne mobile 7
    int mm20_value = iMA(NULL, 0, mm20, 0, MODE_SMA, PRICE_CLOSE); // Valeur de la moyenne mobile 20

    ArraySetAsSeries(myMovingAverrageArray1, true);
    ArraySetAsSeries(myMovingAverrageArray2, true);

    CopyBuffer(mm7_value, 0, 0, 3, myMovingAverrageArray1);
    CopyBuffer(mm20_value, 0, 0, 3, myMovingAverrageArray2);

    int totalPositions = PositionsTotal(); // Obtenir le nombre total de positions ouvertes

    if ((myMovingAverrageArray1[0] > myMovingAverrageArray2[0]) &&
        (myMovingAverrageArray1[1] < myMovingAverrageArray2[1]))
    {
        // fermeture des trades en vente
        if (currentTypeTrade == 2 || currentTypeTrade == 0)
        {
            closeTrade();
        }
        if (totalPositions < sessionTradeMax && (currentTypeTrade == 2 || currentTypeTrade == 0))
        {
            addTrade();
            currentTypeTrade = 1;
            return currentTypeTrade;
        }

        Comment("BUY");
    }

    if ((myMovingAverrageArray1[0] < myMovingAverrageArray2[0]) &&
        (myMovingAverrageArray1[1] > myMovingAverrageArray2[1]))
    {
        // fermeture des trades en achat
        if (currentTypeTrade == 1 || currentTypeTrade == 0)
        {
            closeTrade(false);
        }

        if (totalPositions < sessionTradeMax && (currentTypeTrade == 1 || currentTypeTrade == 0))
        {
            addTrade(false);
            currentTypeTrade = 2;
            return currentTypeTrade;
        }

        Comment("SELL");
    }

    return 0;
}

// verifier si il y a un trade en cours
bool isTrading()
{
    int totalPositions = PositionsTotal(); // Obtenir le nombre total de positions ouvertes
    if (totalPositions > 0)
    {
        // Comment("Trade en cours\n");
    }
    else
    {
        // Comment("Pas de trade en cours\n");
    }

    return totalPositions == 0;
}

// verifie si la position des MM sont en dessous ou dessus de l'axe des ordonnees en params
// au dessus/dessous de l'axe des ordonées au moins avec une distance definie
// si true au dessus sinon en dessous
int isTopDowMM(double y_position, double mm7_value, double mm20_value)
{
    // Vérifie si le croisement est en dessous des deux moyennes mobiles
    bool isTopDow = y_position < mm7_value && y_position < mm20_value;
    if (isTopDow)
    {
        // achat au dessus du y
        return 1;
    }
    isTopDow = y_position > mm7_value && y_position > mm20_value;
    if (isTopDow)
    {
        // vente au en dessous du y
        return 2;
    }

    Comment("Y_position : " + DoubleToString(y_position) + " MM7 : " + DoubleToString(mm7_value) + " MM20 : " + DoubleToString(mm20_value));
    return 0;
}

// l'objectif de gain a ete atteint rester sur le marche
// en acceptant de perdre x% sur benefice en plus sans prendre en compte le pofit
bool isStayMarket()
{
    return true;
}

// si le trade a atteint mon objectif de gain, verifier que je n'ai pas une perte de plus de x% de mon trade
// si l'objectif a ete atteint retourner false
// sinon je ferme le trade on retournant un true si je pert x% si objectif atteint
bool isLoseTargetProfit()
{
    return true;
}

// fermetue du trade du current trade
void closeTrade(bool isBuyOrSell = true)
{
    Comment("CLOSE TRADES");
    //--- déclare et initialise la demande de trading et le résultat
    MqlTradeRequest request;
    MqlTradeResult result;
    int total = PositionsTotal(); // nombre de positions ouvertes
                                  //--- boucle sur toutes les positions ouvertes
    for (int i = total - 1; i >= 0; i--)
    {
        //--- paramètres de l'ordre
        ulong position_ticket = PositionGetTicket(i);                                    // ticket de la position
        string position_symbol = PositionGetString(POSITION_SYMBOL);                     // symbole
        int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS);             // nombre de décimales
        ulong magic = PositionGetInteger(POSITION_MAGIC);                                // MagicNumber de la position
        double volume = PositionGetDouble(POSITION_VOLUME);                              // volume de la position
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // type de la position
        //--- affiche les informations de la position
        PrintFormat("#%I64u %s  %s  %.2f  %s [%I64d]",
                    position_ticket,
                    position_symbol,
                    EnumToString(type),
                    volume,
                    DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), digits),
                    magic);
        //--- si le MagicNumber correspond
        // if((magic == EXPERT_MAGIC) // pour supprimer uniquement ceux du nombre magic
        if (true)
        {
            //--- remise à zéro de la demande et du résultat
            ZeroMemory(request);
            ZeroMemory(result);
            //--- paramètres de l'opration
            request.action = TRADE_ACTION_DEAL; // type de l'opération de trading
            request.position = position_ticket; // ticket de la position
            request.symbol = position_symbol;   // symbole
            request.volume = volume;            // volume de la position
            request.deviation = 5;              // déviation du prix autoriséee
            // request.magic    = EXPERT_MAGIC;         // MagicNumber de la position
            request.type_filling = ORDER_FILLING_IOC;
            //--- définit le prix et le type de l'ordre suivant le type de la position
            if (!isBuyOrSell)
            {
                request.price = SymbolInfoDouble(position_symbol, SYMBOL_BID);
                request.type = ORDER_TYPE_SELL;
            }
            else
            {
                request.price = SymbolInfoDouble(position_symbol, SYMBOL_ASK);
                request.type = ORDER_TYPE_BUY;
            }
            //--- affiche les informations de clôture
            PrintFormat("Ferme #%I64d %s %s", position_ticket, position_symbol, EnumToString(type));
            //--- envoi la demande
            if (!OrderSend(request, result))
                Comment("Order close Send erreur %d", GetLastError()); // en cas d'échec de l'envoi, affiche le code d'erreur
                                                                       //--- informations sur l'opération
                                                                       // PrintFormat("retcode=%u  transaction=%I64u  ordre=%I64u",result.retcode,result.deal,result.order);
                                                                       //---
        }
    }
}

// Ajout d'un trade
void addTrade(bool isBuyOrSell = true)
{
    // Obtenez le solde actuel du compte
    double accountBalance = ACCOUNT_BALANCE;

    // Calculez les montants du stop loss et du take profit
    double stopLossAmount = accountBalance * stopLossPercentage;
    double takeProfitAmount = accountBalance * takeProfitPercentage;

    //--- déclare et initialise la demande de trading et le résultat de la demande
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    //--- paramètres de la demande
    request.action = TRADE_ACTION_DEAL;                                                // type de l'opération de trading
    request.symbol = Symbol();                                                         // symbole
                                                                                       // request.sl       = stopLossAmount;                   // stoplost
                                                                                       // request.tp       = takeProfitAmount;                 // take profit
    request.volume = lotSize;                                                          // volume de 0.1 lot
    request.type = isBuyOrSell ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;                     // type de l'ordre
    request.price = SymbolInfoDouble(Symbol(), isBuyOrSell ? SYMBOL_ASK : SYMBOL_BID); // prix d'ouverture
    request.deviation = 5;                                                             // déviation du prix autorisée
    request.magic = EXPERT_MAGIC;                                                      // MagicNumber de l'ordre
    request.type_filling = ORDER_FILLING_IOC;
    //--- envoi la demande
    if (!OrderSend(request, result))
    {
        // en cas d'erreur d'envoi de la demande, affiche le code d'erreur
        // Comment("OrderSend erreur %d",GetLastError());
    }

    //--- informations de l'opération
    // Comment("retcode=%u  transaction=%I64u  ordre=%I64u",result.retcode,result.deal,result.order);
}

// deplacer le stoplost à la session en cours
void moveStopLost()
{
    //
}

// ajout d'un stop lost au trade à la session en cours
void addStopLost()
{
    //
}

// verifier si la MM200 est plutot orienté de facon horizontal pour avertir d'un range sur une x nombre de periode
// l'idee est de prendre le y point en ordonnee des x derniere periode à maintenant si pas trop de difference : range
bool isRange()
{
    return false;
}

// verifier si la mèche de la bougie est 3 fois plus grande que le corps de la bougie
// si c'est le cas on sort dy trade risque de changement de de tandance
// uniquement si c'est une bougie opposée au sens du marche
bool isWickMoreThanCandle()
{
    return false;
}
//+------------------------------------------------------------------+
