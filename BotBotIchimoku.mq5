//+------------------------------------------------------------------+
//|                                        BotBotIchimokuLiberty.mq5 |
//|                                        Copyright 2024, GenixCode |
//|                                        https://www.genixcode.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, GenixCode"
#property link "https://www.genixcode.com"
#property version "1.10"

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
// #include <Arrays\ArrayInt.mqh>
#include <Indicators/Trend.mqh>

CiIchimoku *Ichimoku;
CiIchimoku *IchimokuMid;
CiIchimoku *IchimokuLow;

input double percentProfit = 0.1; // pourcentage profit sur capital
input double percentRisk = -0.05; // pourcentage risque sur capital
input int numberBot = 20230407;   // identifiant du robot à modifier si marche en double
input int sessionTradeMax = 1;    // nombre de trade maximum pour un bot
input int stopLostVal = 10;       // nombre de point sl
input int moveStopLostValx = 10;  // ajout de la marge du sl
input int profitTarget = 30;      // breakevent sur profit maximal
input double lotSize = 1;         // lot correspondant à 1 EUR par point pour DJ30, DAX, NAS100
input double uTime = 5;           // unité de temps en min : 1, 5 & 15

// gestion du lot en fonction du risque
input double riskLotMini = 1;      // lorsque la tandance est unique à U0
input double riskLotMoyMini = 1.5; // lorsuqe le tendance est U0 identique à (U1 ou U2)
input double riskLotMoy = 2;       // lorsuqe le tendance est U0 identique à (U1 ou U2)
input double riskLotHigh = 3;      // lorsque la tendance identique : U0, U1, U2

// gestion de perte pour fermeture du trade
input double riskLostMini = -20;    // Perte maximal lorsque la tandance est unique à U0
input double riskLostMoyMini = -25; // Perte maximal lorsuqe le tendance est U0 identique à (U1 ou U2)
input double riskLostMoy = -40;     // Perte maximal lorsuqe le tendance est U0 identique à (U1 ou U2)
input double riskLostHigh = -60;    // Perte maximal lorsque la tendance identique : U0, U1, U2

// gestion de profit pour fermer le trade en fonction du lot
input double profitMini = 0;    // profit maximal lorsque la tandance est unique à U0
input double profitMoyMini = 0; // profit maximal lorsuqe le tendance est U0 identique à (U1 ou U2)
input double profitMoy = 0;     // profit maximal lorsuqe le tendance est U0 identique à (U1 ou U2)
input double profitHigh = 0;    // profit maximal lorsque la tendance identique : U0, U1, U2

// gestion du temps de trade
input int hourStartTrade = 9; // heure de debut de trade
input int hourEndTrade = 22;  // heure de fin de trade

bool priceAboveCloud = false;
bool priceLowCloud = false;
string message = "RECHERCHE";

// Variables globales pour stocker les valeurs précédentes de priceAboveCloud et priceLowCloud
bool previousPriceAboveCloud = false;
bool previousPriceLowCloud = false;

int sizeEssouflement = 2;     // nombre de perte concecutif sur une tendance pour verifier un essouflement
int initSizeEssouflement = 2; // init lors de changement de tendance

double iMomentumValx = 0.0;
// gestion management money
double objectifProfitByDay = 180.0; // Montant de la journee à ne pas perdre si atteint depuis le portefeuil
double objectifLostByDay = -75.0;   // objectif de perte maximal par jour du portefeuil
double closeToProfit = 0;           // montant maximal à atteindre pour fermer le trade
double lostTarget = -20.0;          // fermeture du trade si perte maximal
double lotSizeRisk = 2;
int lostByTradeMax = 4;             // nombre de perte par session de trade ou jour
int moveStopLostVal = 5;            // ajout de la marge du sl
double cassureFrancheVal = 0.5;     // definition de la val pour determiner si cassure franche
bool isAddSlSecureByCandle = false; // verfier si la securite a ete ajoute

#define EXPERT_MAGIC numberBot;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  Ichimoku = new CiIchimoku();
  IchimokuMid = new CiIchimoku();
  IchimokuLow = new CiIchimoku();
  if (uTime == 5)
  {
    Ichimoku.Create(_Symbol, PERIOD_M5, 9, 26, 52);
    IchimokuMid.Create(_Symbol, PERIOD_M15, 9, 26, 52);
    IchimokuLow.Create(_Symbol, PERIOD_H1, 9, 26, 52);
  }
  else if (uTime == 15)
  {
    Ichimoku.Create(_Symbol, PERIOD_M15, 9, 26, 52);
    IchimokuMid.Create(_Symbol, PERIOD_H1, 9, 26, 52);
    IchimokuLow.Create(_Symbol, PERIOD_H4, 9, 26, 52);
  }
  else
  {
    Ichimoku.Create(_Symbol, PERIOD_M1, 9, 26, 52);
    IchimokuMid.Create(_Symbol, PERIOD_M5, 9, 26, 52);
    IchimokuLow.Create(_Symbol, PERIOD_M15, 9, 26, 52);
  }

  //+------------------------------------------------------------------+
  //|                                                                  |
  //+------------------------------------------------------------------+
  calculRisk();
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  // Libérez la mémoire de l'objet Ichimoku
  delete Ichimoku;
  delete IchimokuMid;
  delete IchimokuLow;
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  // Mettez à jour les données de l'objet Ichimoku
  Ichimoku.Refresh(-1);
  IchimokuMid.Refresh(-1);
  IchimokuLow.Refresh(-1);

  // Récupère la tendance currente
  double SpanAx1Current = Ichimoku.SenkouSpanA(1);
  double SpanBx1Current = Ichimoku.SenkouSpanB(1);
  int uTimeTendanceCurrentVal = uTimeTendance(SpanAx1Current, SpanBx1Current);

  // double ChinkouSpan = Ichimoku.ChinkouSpan(1);

  // Récupère la tendance de milieu
  double SpanAx1Mid = IchimokuMid.SenkouSpanA(1);
  double SpanBx1Mid = IchimokuMid.SenkouSpanB(1);
  int uTimeTendanceMidVal = uTimeTendance(SpanAx1Mid, SpanBx1Mid);

  // Récupère la tendance de fond
  double SpanAx1Low = IchimokuLow.SenkouSpanA(1);
  double SpanBx1Low = IchimokuLow.SenkouSpanB(1);
  int uTimeTendanceLowVal = uTimeTendance(SpanAx1Low, SpanBx1Low);
  int sameDirectionUTendaneVal = sameDirectionUTendane(uTimeTendanceCurrentVal, uTimeTendanceMidVal, uTimeTendanceLowVal);

  acceptAmountLostTrade();
  aboveLowCloud();

  bool priceInCloud = priceInCloud();
  bool tekanAboveLast2PriceCross = tekanAboveLast2PriceCrossing();
  bool tekanLowLast2Price = tekanLowLast2PriceCrossing();

  bool tekanLowKinjunx = tekanLowKinjun();
  bool tekanAboveKinjunx = tekanAboveKinjun();

  bool tenkanPriceCrossAbove = tenkanPriceCrossing();
  bool tenkanPriceCrossLow = tenkanPriceCrossAbove;
  bool kinjunPriceCrossAbove = kinjunPriceCrossing();
  bool kinjunPriceCrossLow = kinjunPriceCrossAbove;
  bool SenkouSpanAPriceCrossingVal = SenkouSpanAPriceCrossing();

  // int tekanCrossKinjunDirectionVal = tekanCrossKinjunDirection();

  bool bearishCoLorCandlex = bearishColorCandle();
  bool tekanCrossKinjunx = tekanCrossinjun();

  bool isTimeToTradeVal = isTimeToTrade();
  bool chikouIsFreexBuy = chikouIsFree(1);
  bool chikouIsFreexSell = chikouIsFree(2);
  double valGetTotalProfitToday = GetTotalProfitToday();
  // int tekanDirectionVal = tekanDirection();

  // gestion de fermeture
  int totalPositions = PositionsTotal();
  // conditions de fermeture de trade
  bool isCloseBuy = tekanCrossKinjunx || ((kinjunPriceCrossAbove || kinjunPriceCrossLow) && bearishCoLorCandlex);
  bool isCloseSell = tekanCrossKinjunx || ((kinjunPriceCrossAbove || kinjunPriceCrossLow) && !bearishCoLorCandlex);

  // fermeture en fonction du momentum
  bool closeTradeByMomentumtVal = closeTradeByMomentumt();
  bool isPositionOnCurrentCandleVal = isPositionOnCurrentCandle();

  // maj de l'essouflement d'un mouvement tekan/addtrade casse par la bougie au sens du marche
  Essouflement(priceAboveCloud, priceLowCloud, priceInCloud, tenkanPriceCrossAbove, tenkanPriceCrossLow, bearishCoLorCandlex);

  // tech. de tradosaure
  int isAddTradeByCrossTekanKinjunVal = 0;
  if (!isPositionOnCurrentCandleVal && totalPositions <= sessionTradeMax && !closeTradeByMomentumtVal &&
      (isTimeToTradeVal && (valGetTotalProfitToday == 0 || objectifLostByDay < valGetTotalProfitToday)) &&
      (valGetTotalProfitToday < objectifProfitByDay) && !priceInCloud && lostByTradeMax > 0)
  {
    isAddTradeByCrossTekanKinjunVal = isAddTradeByCrossTekanKinjun(
        tekanCrossKinjunx,
        priceAboveCloud,
        priceLowCloud,
        chikouIsFreexBuy,
        chikouIsFreexSell,
        tekanLowKinjunx,
        tekanAboveKinjunx,
        priceInCloud);
  }

  // verfication de sortie si deux bougies baissier
  // ou casure de kinjun par bougie rouge
  if (totalPositions > 0 && priceAboveCloud && isCloseBuy && isAddTradeByCrossTekanKinjunVal == 0)
  {
    // closeTrade(priceAboveCloud);
    message = "CLOSE TRADE ABOVE";
  }
  // cassure kinjun par une bougie verte
  if (totalPositions > 0 && priceLowCloud && isCloseSell && isAddTradeByCrossTekanKinjunVal == 0)
  {
    // closeTrade(!priceLowCloud);
    message = "CLOSE TRADE LOW";
  }

  // initialisation du risk si une nouvel timing
  if (!isTimeToTradeVal)
  {
    calculRisk();
  }

  if (!closeTradeByMomentumtVal && !isPositionOnCurrentCandleVal && totalPositions < sessionTradeMax &&
      !tekanCrossKinjunx && !isCloseBuy && isAddTradeByCrossTekanKinjunVal == 0 &&
      (isTimeToTradeVal && (valGetTotalProfitToday == 0 || objectifLostByDay < valGetTotalProfitToday)) &&
      (valGetTotalProfitToday < objectifProfitByDay) && !priceInCloud && lostByTradeMax > 0)
  {
    // verification si le prix n'es pas dans le nuage
    bool checkAddTrade = checkAddTrade();
    if (priceAboveCloud &&
        chikouIsFreexBuy &&
        tekanAboveKinjunx &&
        (tenkanPriceCrossAbove || SenkouSpanAPriceCrossingVal) &&
        !bearishCoLorCandlex &&
        sizeEssouflement > 0 &&
        isAddTradeByCrossTekanKinjunVal == 0 &&
        // (tenkanPriceCrossAbove || kinjunPriceCrossAbove) &&
        // kinjunPriceCrossAbove &&
        // sameDirectionUTendaneVal > 0 &&
        // tekanDirectionVal == 2 &&
        checkAddTrade)
    {
      addTrade();
      message = "ACHAT";
    }

    if (priceLowCloud &&
        chikouIsFreexSell &&
        tekanLowKinjunx &&
        (tenkanPriceCrossLow || SenkouSpanAPriceCrossingVal) &&
        bearishCoLorCandlex &&
        sizeEssouflement > 0 &&
        isAddTradeByCrossTekanKinjunVal == 0 &&
        // (tenkanPriceCrossLow || kinjunPriceCrossLow) &&
        // kinjunPriceCrossLow &&
        // sameDirectionUTendaneVal > 0 &&
        // tekanDirectionVal == 1 &&
        checkAddTrade)
    {
      addTrade(false);
      message = "VENTE";
    }
  }

  moveStopLost();
  // double TenkanVal= Ichimoku.TenkanSen(1);
  datetime currentTime = TimeCurrent();

  Comment("isTimeToTradeVal : ", isTimeToTradeVal, " : ", TimeToString(currentTime, TIME_DATE | TIME_MINUTES), "\n",
          // "message : ", message, "\n",
          "PnL : ", valGetTotalProfitToday, "\n",
          "lostByTradeMax : ", lostByTradeMax, "\n",
          "objectifProfitByDay : ", objectifProfitByDay, "\n",
          "objectifLostByDay : ", objectifLostByDay, "\n",
          "sameDirectionUTendaneVal U0+U1+U2 : ", sameDirectionUTendaneVal, "\n",
          "uTimeTendanceCurrentVal : ", uTimeTendanceCurrentVal, "\n",
          "uTimeTendanceMidVal : ", uTimeTendanceMidVal, "\n",
          "uTimeTendanceLowVal : ", uTimeTendanceLowVal, "\n",
          "chikouIsFreexBuy : ", chikouIsFreexBuy, "\n",
          "chikouIsFreexSell : ", chikouIsFreexSell, "\n",
          "sizeEssouflement : ", sizeEssouflement, "\n",
          "iMomentumValx : ", iMomentumValx, "\n"
          // "tekanCrossKinjunDirectionVal : ", tekanCrossKinjunDirectionVal, "\n",
          // "DESSOUS : ", priceLowCloud, "\n",
          // "TEKAN CROSS PRICE : ", tenkanPriceCross, "\n",
          // "KINJUN CROSS PRICE : ", kinjunPriceCross, "\n",
          // "tekanAboveKinjunx : ", tekanAboveKinjunx, "\n",
          // "tekanLowKinjunx : ", tekanLowKinjunx, "\n",
          // "2 PRICE LOW TEKAN : ", tekanLowLast2Price, "\n",
          // "TEKAN DIRECTION : ", tekanDirectionVal, "\n",
          // "ChinkouSpan : ", ChinkouSpan, "\n",
          // "2 PRICE ABOVE TEKAN : ", tekanAboveLast2PriceCross, "\n",
          // "TEKAN CROSS KINJUN : ", tekanCrossKinjunx, "\n"
  );
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
  //--
}

//+------------------------------------------------------------------+

//+---------------------------------------------------------------------+
//| fermeture du trade par le momentum en fonction de l'entree du trade |
//+---------------------------------------------------------------------+
bool closeTradeByMomentumt()
{
  bool closeTradeByMomentumtVal = false;
  int totalPositions = PositionsTotal();
  double myIMomentumVal = 0.0;
  double iMomentumVal = 0.0;
  double myPricesArray[];
  ArraySetAsSeries(myPricesArray, true);

  if (uTime == 5)
  {
    iMomentumVal = iMomentum(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
  }
  else if (uTime == 15)
  {
    iMomentumVal = iMomentum(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);
  }
  else
  {
    iMomentumVal = iMomentum(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
  }

  CopyBuffer(iMomentumVal, 0, 0, 3, myPricesArray);
  myIMomentumVal = NormalizeDouble(myPricesArray[0], 2);
  iMomentumValx = myIMomentumVal;

  if (myIMomentumVal < 100.0 && totalPositions > 0 && priceAboveCloud)
  {
    closeTrade(priceAboveCloud);
    closeTradeByMomentumtVal = true;
    Print("STRONG : ", myIMomentumVal);
  }
  if (myIMomentumVal > 99.99 && totalPositions > 0 && priceLowCloud)
  {
    closeTrade(!priceLowCloud);
    closeTradeByMomentumtVal = true;
    Print("WEAK : ", myIMomentumVal);
  }

  if (myIMomentumVal > 99.9 && myIMomentumVal < 100.0)
  {
    Print("NEUTRE MOMENTUM : ", myIMomentumVal);
  }

  return closeTradeByMomentumtVal;
}

//+------------------------------------------------------------------+
//|ajout du trade par croisement lors de changement de tendance      |
//|tech tradosaure ex. en ACHAT:                                     |
//|Prix au-dessus du nuage.                                          |
//|Tenkan croise la Kijunà la hausse,                                |
//|au-dessus du nuage.                                               |
//|Chinkou au-dessus du prix                                         |
//| reponse haussier : 2, baissier : 1 & neutre : 0                  |
//+------------------------------------------------------------------+
int isAddTradeByCrossTekanKinjun(
    bool tekanCrossKinjunx,
    bool priceAboveCloudx,
    bool priceLowCloudx,
    bool chikouIsFreexBuyx,
    bool chikouIsFreexSellx,
    bool tekanLowKinjunx,
    bool tekanAboveKinjunx,
    bool priceInCloudx)
{

  int isAddTradeByCrossTekanKinjunVal = 0;
  int totalPositions = PositionsTotal();

  double SpanAx1 = Ichimoku.SenkouSpanA(1);
  double SpanAx2 = Ichimoku.SenkouSpanA(2);
  double SpanBx1 = Ichimoku.SenkouSpanB(1);
  double SpanBx2 = Ichimoku.SenkouSpanB(2);

  double TenkanSen = Ichimoku.TenkanSen(1);
  double KijunSen = Ichimoku.KijunSen(1);

  bool isTekanAboveLowCloud = TenkanSen > SpanAx2 && TenkanSen > SpanBx2 && TenkanSen > SpanAx1 && TenkanSen > SpanBx1;
  bool isKinjunAboveLowCloud = KijunSen > SpanAx2 && KijunSen > SpanBx2 && KijunSen > SpanAx1 && KijunSen > SpanBx1;

  // Print("TenkanSen : ", TenkanSen, " ==> ", isTekanAboveLowCloud);
  // Print("KijunSen : ", KijunSen, " ==> ", isKinjunAboveLowCloud);

  if (totalPositions < sessionTradeMax &&
      tekanCrossKinjunx &&
      priceAboveCloudx &&
      chikouIsFreexBuyx &&
      ((isTekanAboveLowCloud && isKinjunAboveLowCloud) || priceInCloudx) &&
      tekanAboveKinjunx)
  {
    isAddTradeByCrossTekanKinjunVal = 2;
    calculRisk(riskLostMoyMini, profitMoyMini, riskLotMoyMini);
    // addTrade();
    Print("......ACHAT :", isAddTradeByCrossTekanKinjunVal);
  }
  else if (totalPositions < sessionTradeMax &&
           tekanCrossKinjunx &&
           priceLowCloudx &&
           chikouIsFreexSellx &&
           ((!isTekanAboveLowCloud && !isKinjunAboveLowCloud) || priceInCloudx) &&
           tekanLowKinjunx)
  {
    isAddTradeByCrossTekanKinjunVal = 1;
    calculRisk(riskLostMoyMini, profitMoyMini, riskLotMoyMini);
    // addTrade(false);
    Print(".....VENTE :", isAddTradeByCrossTekanKinjunVal);
  }
  else
  {
    isAddTradeByCrossTekanKinjunVal = 0;
    // Print("NEUTRE :", isAddTradeByCrossTekanKinjunVal);
  }
  return isAddTradeByCrossTekanKinjunVal;
}

//+------------------------------------------------------------------+
//| verifie si sur la bougie actuelle on a une position              |
//+------------------------------------------------------------------+
bool isPositionOnCurrentCandle()
{
  // Vérifier si une position est ouverte sur le symbole actuel
  bool position_opened = PositionSelect(Symbol());
  if (position_opened)
  {
    return true;
  }

  datetime currentCandleTime = iTime(Symbol(), 0, 0);
  int totalPositions = PositionsTotal();
  bool position_found = false;

  for (int i = 0; i < totalPositions && !position_found; i++)
  {
    ulong ticket = PositionGetTicket(i);
    datetime positionOpenTime = PositionGetInteger(POSITION_TIME, ticket);
    datetime positionCloseTime = PositionGetInteger(POSITION_TIME_UPDATE, ticket);

    // Vérifier si la position a été ouverte ou fermée sur la bougie actuelle
    if (positionOpenTime == currentCandleTime || positionCloseTime == currentCandleTime)
    {
      position_found = true;
      break;
    }
  }

  return position_found;
}

//+----------------------------------------------------------------------------+
//|verifier si la tekan a ete casse au moins 3 fois dans le sens de la tendance|
//|pour marquer un essouflement si reste 0                                    |
//+----------------------------------------------------------------------------+
void Essouflement(
    bool priceAboveCloudx,
    bool priceLowCloudx,
    bool priceInCloud,
    bool tenkanPriceCrossAbove,
    bool tenkanPriceCrossLow,
    bool bearishCoLorCandlex)
{
  if (priceAboveCloudx != previousPriceAboveCloud || priceLowCloudx != previousPriceLowCloud || priceInCloud)
  {
    sizeEssouflement = initSizeEssouflement;
  }
  else if (sizeEssouflement > 0 && !priceInCloud &&
           ((tenkanPriceCrossAbove && !bearishCoLorCandlex == priceAboveCloudx) ||
            (tenkanPriceCrossLow && bearishCoLorCandlex == priceLowCloudx)))
  {
    // sizeEssouflement--;
  }
  else
  {
    // Autre traitement si nécessaire
  }

  // Mettre à jour les valeurs précédentes
  previousPriceAboveCloud = priceAboveCloudx;
  previousPriceLowCloud = priceLowCloudx;
}

//+------------------------------------------------------------------+
//| Croisement à la hausse:2, baisse : 1, neutre:0                   |
//+------------------------------------------------------------------+
int tekanCrossKinjunDirection()
{
  Ichimoku.Refresh(-1);

  double previousTenkanValues[2]; // Définir la taille du tableau à 2
  double previousKijunValues[2];  // Définir la taille du tableau à 2

  CopyBuffer(Ichimoku.Handle(), 0, 0, 3, previousTenkanValues);
  CopyBuffer(Ichimoku.Handle(), 0, 0, 1, previousKijunValues);

  double currentTenkan = previousTenkanValues[0];
  double previousTenkan = previousTenkanValues[1];

  double currentKijun = previousKijunValues[0];
  double previousKijun = previousKijunValues[1];

  Print("currentTenkan : ", currentTenkan);
  Print("previousTenkan : ", previousTenkan);
  Print("currentKijun : ", currentKijun);
  Print("previousKijun : ", previousKijun);

  int crossingSignal = 0; // Initialisation du signal de croisement

  // Si la Tenkan-sen croise à la hausse la Kijun-sen
  if (previousTenkan < previousKijun && currentTenkan > currentKijun)
  {
    crossingSignal = 2; // Croisement à la hausse
  }
  // Si la Tenkan-sen croise à la baisse la Kijun-sen
  else if (previousTenkan > previousKijun && currentTenkan < currentKijun)
  {
    crossingSignal = 1; // Croisement à la baisse
  }
  // Sinon, aucun croisement
  else
  {
    crossingSignal = 0;
  }

  return crossingSignal;

  // Maintenant crossingSignal contiendra 0 pour aucun croisement,
  // 1 pour un croisement à la baisse, 2 pour un croisement à la hausse
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int tekanDirection()
{
  double TenkanSen = Ichimoku.TenkanSen(1);
  double previousTenkanValues[];
  ArraySetAsSeries(previousTenkanValues, true);
  int copied = CopyBuffer(TenkanSen, 0, 0, 3, previousTenkanValues);

  if (copied < 2)
  {
    Print("Erreur lors de la récupération des valeurs de la Tenkan-sen.");
    return 0; // Impossible de déterminer la direction
  }

  if (previousTenkanValues[0] < previousTenkanValues[1])
  {
    return 1; // Direction baissière
  }
  else if (previousTenkanValues[0] > previousTenkanValues[1])
  {
    return 2; // Direction haussière
  }
  else
  {
    return 0; // Direction indéterminée
  }
}

//+------------------------------------------------------------------+
//| verification de la concordance de temps U0 + U1 & U2             |
//| faible:1,moyen:2,3,forte:4                                       |
//+------------------------------------------------------------------+
int sameDirectionUTendane(int currentUT, int midUT, int lowUT)
{
  int sameDirectionUTendane = 0;
  if ((currentUT == 0 || currentUT == 2) && midUT == 1 && lowUT == 1)
  {
    calculRisk(riskLostMoyMini, profitMoyMini, riskLotMoyMini);
    sameDirectionUTendane = 1;
  }
  else if ((currentUT == 0 || currentUT == 2) && currentUT == midUT && lowUT == 1)
  {
    calculRisk(riskLostMoy, profitMoy, riskLotMoy);
    sameDirectionUTendane = 2;
  }
  else if ((currentUT == 0 || currentUT == 2) && currentUT == 1 && (lowUT == 0 || lowUT == 2))
  {
    calculRisk(riskLostMoy, profitMoy, riskLotMoy);
    sameDirectionUTendane = 3;
  }
  else if ((currentUT == 0 || currentUT == 2) && currentUT == lowUT && lowUT == currentUT)
  {
    calculRisk(riskLostHigh, profitHigh, riskLotHigh);
    sameDirectionUTendane = 4;
  }
  else
  {
    calculRisk(riskLostHigh, profitMini, riskLotMini);
    sameDirectionUTendane = 0;
  }
  return sameDirectionUTendane;
}

//+------------------------------------------------------------------+
//| tendance haussiere = 2, range = 1, baissiere = 0                 |
//+------------------------------------------------------------------+
int uTimeTendance(double SpanAx1, double SpanBx1)
{
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);

  // Le prix est-il au-dessus du nuage ?
  if (last_close > SpanAx1 && last_open > SpanAx1 && last_close > SpanBx1 && last_open > SpanBx1)
  {
    return 2; // Prix au-dessus du nuage
  }

  // Le prix est-il en dessous du nuage ?
  if (last_close < SpanAx1 && last_open < SpanAx1 && last_close < SpanBx1 && last_open < SpanBx1)
  {
    return 0; // Prix en dessous du nuage
  }

  // Sinon, le prix est dans le nuage
  return 1;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTotalProfitToday()
{
  MqlDateTime SDateTime;
  TimeToStruct(TimeCurrent(), SDateTime);

  SDateTime.hour = 0;
  SDateTime.min = 0;
  SDateTime.sec = 0;
  datetime from_date = StructToTime(SDateTime); // From date

  SDateTime.hour = 23;
  SDateTime.min = 59;
  SDateTime.sec = 59;
  datetime to_date = StructToTime(SDateTime); // To date
  to_date += 60 * 60 * 24;

  HistorySelect(from_date, to_date);
  int trades_of_day = 0;
  double wining_trade = 0.0;
  double losing_trade = 0.0;
  double total_profit = 0.0;
  uint total = HistoryDealsTotal();
  ulong ticket = 0;
  //--- for all deals
  for (uint i = 0; i < total; i++)
  {
    //--- try to get deals ticket
    if ((ticket = HistoryDealGetTicket(i)) > 0)
    {
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if (entry == DEAL_ENTRY_IN)
        continue;
      //--- get deals properties
      trades_of_day++;
      double deal_commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double deal_swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double deal_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double profit = deal_commission + deal_swap + deal_profit;
      if (profit > 0.0)
        wining_trade += profit;
      if (profit < 0.0)
        losing_trade += profit;
      total_profit += profit;
    }
  }

  return total_profit;
}

//+------------------------------------------------------------------+
//| calcule risque perte, profit & lot                               |
//+------------------------------------------------------------------+
void calculRisk(
    double lostTargetVal = -30,
    double closeToProfitVal = 0,
    double lotSizeRiskVal = 1,
    int moveStopLostValParam = 20)
{
  double capital = AccountInfoDouble(ACCOUNT_BALANCE);
  objectifProfitByDay = 1000;           // (capital * percentProfit) * 4;
  objectifLostByDay = 3 * riskLostHigh; // (capital * percentRisk) * 4;
  lostTarget = lostTargetVal;           // capital * percentRisk;
  closeToProfit = closeToProfitVal;     // capital * percentProfit;
  lotSizeRisk = lotSizeRiskVal;
  moveStopLostVal = moveStopLostValParam;
  lostByTradeMax = 4;
}

// verifie si le prix se situe en dessous ou au dessus du nuage SI TRUE au dessus du nuage
void aboveLowCloud()
{
  double SpanAx1 = Ichimoku.SenkouSpanA(1);
  double SpanAx2 = Ichimoku.SenkouSpanA(2);

  double SpanBx1 = Ichimoku.SenkouSpanB(1);
  double SpanBx2 = Ichimoku.SenkouSpanB(2);

  // Récupérer le prix de clôture de la dernière bougie
  double close1 = iClose(Symbol(), 0, 1);
  double close2 = iClose(Symbol(), 0, 2);

  // le prix est au dessus des nuages
  if (!priceAboveCloud && (close2 < SpanAx2 || close2 < SpanBx2) && close1 > SpanAx1 && close1 > SpanBx1)
  {
    priceAboveCloud = true;
    priceLowCloud = false;
  }

  if (!priceLowCloud && (close2 > SpanAx2 || close2 > SpanBx2) && close1 < SpanAx1 && close1 < SpanBx1)
  {
    priceAboveCloud = false;
    priceLowCloud = true;
  }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| retourne true si le prix est dans le nuage                       |
//+------------------------------------------------------------------+
bool priceInCloud()
{
  double SpanAx1 = Ichimoku.SenkouSpanA(1);
  double SpanBx1 = Ichimoku.SenkouSpanB(1);

  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);
  bool isRange = last_close < SpanAx1 && last_open < SpanAx1 && last_close > SpanBx1 && last_open > SpanBx1;
  return isRange;
}

//+------------------------------------------------------------------+
//| cassure ou rebond sur la ssa en fonction du sens du marche       |
//+------------------------------------------------------------------+
bool SenkouSpanAPriceCrossing()
{
  double SenkouSpanAVal = Ichimoku.SenkouSpanA(1);
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);
  double last_high = iHigh(Symbol(), 0, 1);
  double last_low = iLow(Symbol(), 0, 1);

  bool upperWickCross = false;
  bool lowerWickCross = false;

  double upperWick = last_high - MathMax(last_open, last_close);
  double lowerWick = MathMin(last_open, last_close) - last_low;

  int totalPositions = PositionsTotal();

  bool priceInCloudVal = priceInCloud();

  double corps_longueur = MathAbs(last_close - last_open);
  double meche_longueur_superieure = last_high - MathMax(last_open, last_close);
  double meche_longueur_inferieure = MathMin(last_open, last_close) - last_low;
  double meche_longueur_totale = meche_longueur_superieure + meche_longueur_inferieure;
  // La mèche est au moins deux fois plus longue que le corps de la bougie.
  bool isWickTwiceLonger = corps_longueur > 0 && meche_longueur_totale >= (2 * corps_longueur);

  if (!priceInCloudVal && priceAboveCloud && totalPositions < sessionTradeMax && isWickTwiceLonger)
  {
    lowerWickCross = lowerWick > 0 && last_low < SenkouSpanAVal && last_close > SenkouSpanAVal;
  }
  if (!priceInCloudVal && priceLowCloud && totalPositions < sessionTradeMax && isWickTwiceLonger)
  {
    upperWickCross = upperWick > 0 && last_high > SenkouSpanAVal && last_close > SenkouSpanAVal;
  }

  if (upperWickCross || lowerWickCross)
  {
    calculRisk(riskLostMoy, profitMoy, riskLotMoy);
  }

  // Retourner true si l'une des mèches croise la Senkou Span A
  // return upperWickCross || lowerWickCross;
  return false;
}

// le prix la croise la tenkan & verif casssure franche
bool tenkanPriceCrossing()
{
  double TenkanVal = Ichimoku.TenkanSen(1);
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);
  double last_high = iHigh(Symbol(), 0, 1);
  double last_low = iLow(Symbol(), 0, 1);

  bool tenkanPriceCross = false;
  bool isCassureFranche = false;

  // gestion du rebond sur la tenkan cassure à partir de la meche
  bool upperWickCross = last_high > TenkanVal && last_close > TenkanVal && last_open < TenkanVal;
  bool lowerWickCross = last_low < TenkanVal && last_close < TenkanVal && last_open > TenkanVal;
  if (upperWickCross || lowerWickCross)
  {
    double corps_longueur = MathAbs(last_close - last_open);
    double meche_longueur_superieure = last_high - MathMax(last_open, last_close);
    double meche_longueur_inferieure = MathMin(last_open, last_close) - last_low;
    double meche_longueur_totale = meche_longueur_superieure + meche_longueur_inferieure;
    // La mèche est au moins deux fois plus longue que le corps de la bougie.
    bool isWickTwiceLonger = meche_longueur_totale >= 0.5 * corps_longueur;
    tenkanPriceCross = isWickTwiceLonger;
  }
  if (!tenkanPriceCross)
  {
    tenkanPriceCross = (last_open > TenkanVal && last_close < TenkanVal) ||
                       (last_open < TenkanVal && last_close > TenkanVal);

    // verification cassure franche
    isCassureFranche = MathAbs((TenkanVal - last_open)) > cassureFrancheVal &&
                       MathAbs((TenkanVal - last_close)) > cassureFrancheVal;
    // quand la cassure n'est pas franche passe au mini
    if (!isCassureFranche && tenkanPriceCross)
    {
      calculRisk(riskLostHigh, profitMini, riskLotMini, 10);
    }
  }

  return tenkanPriceCross;
}

//+-----------------------------------------------------------------------+
//|prix qui casse la kinjun ou rebond : isBuyOrSell false buy & true sell |
//+-----------------------------------------------------------------------+
bool kinjunPriceCrossing()
{
  double KijunVal = Ichimoku.KijunSen(1);
  double last_low = iLow(Symbol(), 0, 1);
  double last_high = iHigh(Symbol(), 0, 1);
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);

  bool isCassureFranche = false;
  bool isKinjunPriceCross = false;

  // Définition des variables
  double corps_longueur = MathAbs(last_close - last_open);
  double meche_longueur_superieure = last_high - last_close;
  double meche_longueur_inferieure = last_open - last_low;
  double meche_longueur_totale = meche_longueur_superieure + meche_longueur_inferieure;

  // Vérifier si la mèche est deux fois plus longue que le corps pour identifier le rebond
  if (meche_longueur_totale > (2 * corps_longueur))
  {
    isKinjunPriceCross = (last_high > KijunVal && last_low < KijunVal) ||
                         (last_high < KijunVal && last_low > KijunVal);
    // verification cassure franche
    isCassureFranche = MathAbs((KijunVal - last_high)) > cassureFrancheVal &&
                       MathAbs((KijunVal - last_low)) > cassureFrancheVal;
  }
  else
  {
    isKinjunPriceCross = (last_open > KijunVal && last_close < KijunVal) ||
                         (last_open < KijunVal && last_close > KijunVal);
    // verification cassure franche
    isCassureFranche = MathAbs((KijunVal - last_open)) > cassureFrancheVal &&
                       MathAbs((KijunVal - last_close)) > cassureFrancheVal;
  }

  if (!isCassureFranche)
  {
    calculRisk(riskLostHigh, profitMini, riskLotMini, 10);
  }

  return isKinjunPriceCross;
}
// verifier si la tenkan est au dessus des prix
bool tekanAboveLast2PriceCrossing()
{
  double TenkanVal = Ichimoku.TenkanSen(1);
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);

  double last_close_2 = iClose(Symbol(), 0, 2);
  double last_open_2 = iOpen(Symbol(), 0, 2);

  bool tenkanLowPriceCross = last_open > TenkanVal && last_close > TenkanVal && last_open_2 > TenkanVal && last_close_2 > TenkanVal;
  return tenkanLowPriceCross;
}
// verfier si la tenkan est en dessous des prix sur les deux derniere bougie
bool tekanLowLast2PriceCrossing()
{
  double TenkanVal = Ichimoku.TenkanSen(1);
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);

  double last_close_2 = iClose(Symbol(), 0, 2);
  double last_open_2 = iOpen(Symbol(), 0, 2);

  bool tenkanLowPriceCross = last_open < TenkanVal && last_close < TenkanVal && last_open_2 < TenkanVal && last_close_2 < TenkanVal;
  return tenkanLowPriceCross;
}

// verifie que la tenkan est en dessous
bool tekanAboveKinjun()
{
  double TenkanVal = Ichimoku.TenkanSen(1);
  double KijunVal = Ichimoku.KijunSen(1);
  bool valTekanLowKinjun = TenkanVal >= KijunVal;
  return valTekanLowKinjun;
}

// verifie que la tenkan est en dessous
bool tekanLowKinjun()
{
  double TenkanVal = Ichimoku.TenkanSen(1);
  double KijunVal = Ichimoku.KijunSen(1);
  bool valTekanLowKinjun = TenkanVal <= KijunVal;
  return valTekanLowKinjun;
}
// verifie si la tenkan croise la kinjun
bool tekanCrossinjun()
{
  // Obtenir les valeurs actuelles de la Tenkan-sen et de la Kijun-sen
  double TenkanVal = Ichimoku.TenkanSen(1);
  double KijunVal = Ichimoku.KijunSen(1);

  // Obtenir les valeurs précédentes de la Tenkan-sen et de la Kijun-sen
  double TenkanValPrev = Ichimoku.TenkanSen(2);
  double KijunValPrev = Ichimoku.KijunSen(2);

  // Vérifier si la Tenkan-sen croise la Kijun-sen
  bool tenkanCrossesKijun = (TenkanValPrev < KijunValPrev && TenkanVal > KijunVal) ||
                            (TenkanValPrev == KijunValPrev) || (TenkanVal == KijunVal) ||
                            (TenkanValPrev > KijunValPrev && TenkanVal < KijunVal);

  // Retourner true si le croisement a été détecté, sinon false
  return tenkanCrossesKijun;
}

//+------------------------------------------------------------------+
//| verifie la couleur de la bougie haussiere true & false baissiere |
//+------------------------------------------------------------------+
bool bearishColorCandle()
{
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);
  return last_open > last_close;
}
//+--------------------------------------------------------------------------------------+
//| ajout du stoplost en dessous de la bougie qui a casse une des droites                |
//| je recupere le prix le plus bas si c'est un achat et le plus haut si c'est une vente |
//+--------------------------------------------------------------------------------------+
double addStopLostByCandle(int positionCandle = 2, double margeSL = 0)
{
  double last_low = iLow(Symbol(), 0, positionCandle);
  double last_high = iHigh(Symbol(), 0, positionCandle);
  double lowHigh = MathAbs(last_high - last_low);
  double slost = 0;

  if (lowHigh > 14)
  {
    // positionCandle = 0;
  }

  bool bearishCoLorCandlex = bearishColorCandle();
  if (!bearishCoLorCandlex)
  {
    slost = iLow(Symbol(), 0, positionCandle);
    slost = slost + margeSL;
  }
  else
  {
    slost = iHigh(Symbol(), 0, positionCandle);
    slost = slost - margeSL;
  }
  return slost;
}

// ajout du stop lost en fonction de la position de la kinjun
double addStopLost()
{
  double KijunVal = Ichimoku.KijunSen(0);
  return KijunVal;
}

// Ajout d'un trade
void addTrade(bool isBuyOrSell = true)
{

  int totalPositions = PositionsTotal();

  // verification de la taille de la bougie precedente
  double last_low = iLow(Symbol(), 0, 1);
  double last_high = iHigh(Symbol(), 0, 1);
  double lowHigh = MathAbs(last_high - last_low);

  if (totalPositions < sessionTradeMax && lowHigh < 23)
  {
    // TODO ne pas ajouter de trade si span a & span b horizontal
    string position_symbol = PositionGetString(POSITION_SYMBOL);         // symbole
    int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS); // nombre de décimales
    double price = PositionGetDouble(POSITION_PRICE_OPEN);
    double bid = SymbolInfoDouble(position_symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(position_symbol, SYMBOL_ASK);
    int stop_level = (int)SymbolInfoInteger(position_symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double sl = PositionGetDouble(POSITION_SL); // Stop Loss de la position
    double tp = PositionGetDouble(POSITION_TP); // Take Profit de la position

    //--- calcul et arrondi des valeurs du Stop Loss et du Take Profit
    // price_level=stop_level*SymbolInfoDouble(position_symbol,SYMBOL_POINT);
    // ajouter le sl en fonction de la position de la droite mm20
    // double valAddStopLost = addStopLost();
    double valAddStopLost = addStopLostByCandle();
    double price_level = valAddStopLost;

    if (isBuyOrSell)
    {
      // sl=NormalizeDouble(bid-price_level,digits);
      // tp=NormalizeDouble(bid+price_level,digits);
      sl = valAddStopLost - stopLostVal;
    }
    else
    {
      // sl=NormalizeDouble(ask+price_level,digits);
      // tp=NormalizeDouble(ask-price_level,digits);
      sl = valAddStopLost + stopLostVal;
    }

    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    //--- paramètres de la demande
    request.action = TRADE_ACTION_DEAL; // type de l'opération de trading
    request.symbol = Symbol();          // symbole
    request.sl = sl;                    // stoplost
    // request.tp       = tp;                            // take profit
    request.volume = lotSizeRisk;                                                      // volume de 0.1 lot
    request.type = isBuyOrSell ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;                     // type de l'ordre
    request.price = SymbolInfoDouble(Symbol(), isBuyOrSell ? SYMBOL_ASK : SYMBOL_BID); // prix d'ouverture
    request.deviation = 5;                                                             // déviation du prix autorisée
    request.magic = numberBot;                                                         // MagicNumber de l'ordre
    request.type_filling = ORDER_FILLING_IOC;

    //--- envoi la demande
    if (!OrderSend(request, result))
    {
      // en cas d'erreur d'envoi de la demande, affiche le code d'erreur
      Print("Add TRADE OrderSend erreur %d", GetLastError());
    }

    if (OrderSend(request, result))
    {
      sizeEssouflement--;
    }
  }
}

// fermetue du trade du current trade
void closeTrade(bool isBuyOrSell = true)
{
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
    //--- si le MagicNumber correspond
    if (magic == numberBot)
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
      request.magic = numberBot;          // MagicNumber de la position
      request.type_filling = ORDER_FILLING_IOC;
      //--- définit le prix et le type de l'ordre suivant le type de la position
      if (isBuyOrSell)
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
        Comment("Order close Send erreur %d", GetLastError());

      isAddSlSecureByCandle = false;
    }
  }
}

// si perte autorise atteint ou si marge sur profit atteint en perte
void acceptAmountLostTrade()
{
  MqlTradeRequest request;
  MqlTradeResult result;
  int total = PositionsTotal();
  //--- boucle sur toutes les positions ouvertes
  for (int i = total - 1; i >= 0; i--)
  {
    //--- paramètres de l'ordre
    ulong position_ticket = PositionGetTicket(i);                        // ticket de la position
    string position_symbol = PositionGetString(POSITION_SYMBOL);         // symbole
    int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS); // nombre de décimales
    ulong magic = PositionGetInteger(POSITION_MAGIC);                    // MagicNumber de la position
    double volume = PositionGetDouble(POSITION_VOLUME);
    double currentProfit = PositionGetDouble(POSITION_PROFIT);                       // Profit actuel de la position                                // volume de la position
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // type de la position

    // on verfie si on atteint l'objectif de perte de trade pour fermer
    if (magic == numberBot && lostTarget >= currentProfit)
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
      request.magic = numberBot;          // MagicNumber de la position
      request.type_filling = ORDER_FILLING_IOC;

      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
        request.price = SymbolInfoDouble(position_symbol, SYMBOL_BID);
        request.type = ORDER_TYPE_SELL;
      }
      else
      {
        request.price = SymbolInfoDouble(position_symbol, SYMBOL_ASK);
        request.type = ORDER_TYPE_BUY;
      }
      if (!OrderSend(request, result))
        Comment("acceptAmountLostTrade Send erreur %d", GetLastError());

      lostByTradeMax--;
      isAddSlSecureByCandle = false;
    }
  }
}
//+-----------------------------------------------------------------------+
//| verifier si il atteint closeToProfit pour la premier fois             |
//| et mettre le stop lost à la bougie au dessus de la bougie precedente  |
//+-----------------------------------------------------------------------+
double addSlSecureByCandle()
{
  isAddSlSecureByCandle = true;
  double valAddStopLost = addStopLostByCandle(0, 1);

  // Print("SL SECURE : ", valAddStopLost);
  return valAddStopLost;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void moveStopLost()
{
  //--- déclare et initialise la demande de trade et le résultat
  MqlTradeRequest request;
  MqlTradeResult result;
  int total = PositionsTotal(); // nombre de positions ouvertes
  double TenkanVal = Ichimoku.TenkanSen(1);
  //--- boucle sur toutes les positions ouvertes
  for (int i = 0; i < total; i++)
  {
    //--- paramètres de l'ordre
    ulong position_ticket = PositionGetTicket(i);                        // ticket de la position
    string position_symbol = PositionGetString(POSITION_SYMBOL);         // symbole
    int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS); // nombre de décimales
    double sl = PositionGetDouble(POSITION_SL);                          // Stop Loss de la position
    double tp = PositionGetDouble(POSITION_TP);                          // Take Profit de la position
    double currentProfit = PositionGetDouble(POSITION_PROFIT);           // Profit actuel de la position
    ulong magic = PositionGetInteger(POSITION_MAGIC);

    double stopLossLevel = TenkanVal;
    // stopLossLevel = addStopLostByOnOpenProfit(stopLossLevel);

    //--- si le Stop Loss et le Take Profit ne sont pas définis
    if (magic == numberBot && currentProfit >= profitTarget &&
        ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && sl < stopLossLevel) ||
         (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && sl > stopLossLevel)))
    {
      // verif pour que le sl ne recule pas
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && sl <= stopLossLevel)
        // stopLossLevel = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + stopLossDistance, digits);
        stopLossLevel = stopLossLevel - moveStopLostVal;

      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && sl >= stopLossLevel)
        // stopLossLevel = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - stopLossDistance, digits);
        stopLossLevel = stopLossLevel + moveStopLostVal;

      // verifier si closeToProfit atteint pour la premier fois
      // et mettre le stop lost à la bougie precedente
      if (!isAddSlSecureByCandle && closeToProfit > 0 && currentProfit >= closeToProfit)
      {
        stopLossLevel = addSlSecureByCandle();
      }

      //--- remise à zéro de la demande et du résultat
      ZeroMemory(request);
      ZeroMemory(result);

      //--- définition des paramètres de l'opération
      request.action = TRADE_ACTION_SLTP; // type de l'opération de trading
      request.position = position_ticket; // ticket de la position
      request.symbol = position_symbol;   // symbole
      request.sl = stopLossLevel;         // Stop Loss de la position
      request.magic = numberBot;          // MagicNumber de la position

      //--- envoi de la demande
      if (!OrderSend(request, result))
        PrintFormat("OrderSend erreur %d", GetLastError()); // en cas d'échec de l'envoi, affiche le code de l'erreur

      // verifier si renseigner pour sortir le profit atteint
      if (closeToProfit > 0 && currentProfit >= closeToProfit)
      {
        // closeTrade(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      }
    }
  }
}

//+-----------------------------------------------------------------------------------+
//| ajout du sl si le profitTarget atteint & que la tenkan < au prix actuelle bougie  |
//| & le current profit >= à l'objectif mettre le sl au à 10 points d'entree du prix  |
//+---------------------------------------------------------------------------------+
double addStopLostByOnOpenProfit(double addSlVal)
{
  double price = PositionGetDouble(POSITION_PRICE_OPEN);
  double currentProfit = PositionGetDouble(POSITION_PROFIT);
  double TenkanVal = Ichimoku.TenkanSen(0);
  double sprice = 0;

  bool bearishCoLorCandlex = bearishColorCandle();
  if (!bearishCoLorCandlex)
  {
    sprice = iLow(Symbol(), 0, 0);
  }
  else
  {
    sprice = iHigh(Symbol(), 0, 0);
  }

  if (profitTarget <= currentProfit && TenkanVal < sprice)
  {
    addSlVal = price; //  + bearishCoLorCandlex ? 5 : -5;
  }

  return addSlVal;
}

// Vérifie si un nouveau trade peut être ajouté en fonction du EXPERT_MAGIC courant
bool checkAddTrade()
{
  // Récupérer le nombre de positions ouvertes
  int total = PositionsTotal();
  int positionsWithCurrentMagic = 0;

  // Boucle sur toutes les positions ouvertes
  for (int i = 0; i < total; i++)
  {
    // Récupérer le numéro magique de la position
    ulong magic = PositionGetInteger(POSITION_MAGIC);
    if (magic == numberBot)
    {
      positionsWithCurrentMagic++;
    }
  }
  return positionsWithCurrentMagic < sessionTradeMax;
}

//+------------------------------------------------------------------+
//| ajout des herues de trading par default 9h à 22h                 |
//+------------------------------------------------------------------+
bool isTimeToTrade()
{
  bool isTimeTOTradeVal = true;
  MqlDateTime rightNow;
  TimeToStruct(TimeCurrent(), rightNow);

  // Vérifier si le jour actuel n'est pas un samedi (6) ou un dimanche (0)
  if (rightNow.hour >= hourStartTrade && rightNow.hour < hourEndTrade && rightNow.day_of_week != 6 && rightNow.day_of_week != 0)
  {
    isTimeTOTradeVal = true;
  }
  else
  {
    isTimeTOTradeVal = false;
  }
  return isTimeTOTradeVal;
}

// gestion du filtre par la chinkou
// la chikou est libre de tendance et n'a pas d'obstacle devant lui (soit 10 bougie)
// verifier si la 26eme bougie en arriere croise la chekou
// verifier si la chekou se trouve dans le nuage
// NB : si achat on prend le prix de fermeture & on verfie si la 26eme bougie en arriere
// peut contenir le en fonction de son plus haut & plus bas le prix de la fermeture
bool chikouIsFree(int typeOrderChikou)
{
  bool isChikouAboveLowCloud = false;
  bool isChikouObstacle = true;
  bool isTenkanObstacle = false;
  bool isKijunSenObstacle = false;

  int nbCandles = 26;
  // joue le role de la chikou
  double current_price = iClose(Symbol(), 0, 1);
  // double SpanAx1= Ichimoku.SenkouSpanA(26);
  // double SpanBx1= Ichimoku.SenkouSpanB(26);

  // si achat
  if (typeOrderChikou == 1)
  {
    // isChikouAboveLowCloud = current_price > SpanAx1 && current_price > SpanBx1;
    // obstacle devant la chikou verifie si le high de la bougie soit inferieur au prix de la chikou
    // obstacle à la chikou sur 5 bougie
    for (int nbCandle = nbCandles; nbCandle >= 16; nbCandle--)
    {
      // verifier si la kinjun ne fait pas obstacle
      double KijunSenVal = Ichimoku.KijunSen(nbCandle);
      isKijunSenObstacle = current_price > KijunSenVal && current_price > KijunSenVal;
      if (!isKijunSenObstacle)
      {
        break;
      }
      // verifier si la tekan ne fait pas obstacle
      double TenkanSenVal = Ichimoku.TenkanSen(nbCandle);
      isTenkanObstacle = current_price > TenkanSenVal && current_price > TenkanSenVal;
      if (!isTenkanObstacle)
      {
        break;
      }
      // verifier si en face la chikou n'a pas d'obstacle de nuage devant
      double SpanAx1 = Ichimoku.SenkouSpanA(nbCandle);
      double SpanBx1 = Ichimoku.SenkouSpanB(nbCandle);
      isChikouAboveLowCloud = current_price > SpanAx1 && current_price > SpanBx1;
      if (!isChikouAboveLowCloud)
      {
        break;
      }
      // verfier si pas de bougie devant lui
      double highCandle = iOpen(Symbol(), 0, nbCandle);
      double lowCandle = iClose(Symbol(), 0, nbCandle);
      isChikouObstacle = highCandle < current_price && lowCandle < current_price;
      if (!isChikouObstacle)
      {
        break;
      }
    }
  }
  // si vente
  if (typeOrderChikou == 2)
  {
    // isChikouAboveLowCloud = current_price < SpanAx1 && current_price < SpanBx1;
    for (int nbCandle = nbCandles; nbCandle >= 16; nbCandle--)
    {
      // verifier si la kinjun ne fait pas obstacle
      double KijunSenVal = Ichimoku.KijunSen(nbCandle);
      isKijunSenObstacle = current_price > KijunSenVal && current_price > KijunSenVal;
      if (!isKijunSenObstacle)
      {
        break;
      }
      // verifier si la tekan ne fait pas obstacle
      double TenkanSenVal = Ichimoku.TenkanSen(nbCandle);
      isTenkanObstacle = current_price > TenkanSenVal && current_price > TenkanSenVal;
      if (!isTenkanObstacle)
      {
        break;
      }

      // verifier si en face la chikou n'a pas d'obstacle de nuage devant
      double SpanAx1 = Ichimoku.SenkouSpanA(nbCandle);
      double SpanBx1 = Ichimoku.SenkouSpanB(nbCandle);
      isChikouAboveLowCloud = current_price < SpanAx1 && current_price < SpanBx1;
      if (!isChikouAboveLowCloud)
      {
        break;
      }
      // verifier si pas d'obstacle de bougie devant lui
      double highCandle = iOpen(Symbol(), 0, nbCandle);
      double lowCandle = iClose(Symbol(), 0, nbCandle);
      isChikouObstacle = highCandle > current_price && lowCandle > current_price;
      if (!isChikouObstacle)
      {
        break;
      }
    }
  }

  // Comment("CHIKOU FREE: ",chikouWithin26BackPrices,"\n",
  //         "SELL/ACHAT : ",typeOrderChikou,"\n",
  //         "CHIKOU : ",current_price,"\n",
  //         "HIGH PRICE : ", high_26,"\n",
  //         "LOW PRICE : ", low_26,"\n");
  //
  return isChikouAboveLowCloud && isChikouObstacle && isTenkanObstacle && isKijunSenObstacle;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
