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
#include <Arrays\ArrayInt.mqh>
#include <Indicators/Trend.mqh>

CiIchimoku *Ichimoku;
CiIchimoku *IchimokuMid;
CiIchimoku *IchimokuLow;

input double percentProfit = 0.1; // pourcentage profit sur capital
input double percentRisk = -0.05; // pourcentage risque sur capital
input double uTime = 5;           // unité de temps en min : 1, 5 & 15

// gestion du lot en fonction du risque
input double riskLotMini = 0.5;  // lorsque la tandance est unique à U0
input double riskLotMoyMini = 1; // lorsuqe le tendance est U0 identique à (U1 ou U2)
input double riskLotMoy = 2;     // lorsuqe le tendance est U0 identique à (U1 ou U2)
input double riskLotHigh = 3;    // lorsque la tendance identique : U0, U1, U2

// gestion de perte pour fermeture du trade
input double riskLostMini = -15;    // Perte maximal lorsque la tandance est unique à U0
input double riskLostMoyMini = -20; // Perte maximal lorsuqe le tendance est U0 identique à (U1 ou U2)
input double riskLostMoy = -30;     // Perte maximal lorsuqe le tendance est U0 identique à (U1 ou U2)
input double riskLostHigh = -40;    // Perte maximal lorsque la tendance identique : U0, U1, U2

// gestion de profit pour fermer le trade en fonction du lot
input double profitMini = 0;     // profit maximal lorsque la tandance est unique à U0
input double profitMoyMini = 15; // profit maximal lorsuqe le tendance est U0 identique à (U1 ou U2)
input double profitMoy = 0;      // profit maximal lorsuqe le tendance est U0 identique à (U1 ou U2)
input double profitHigh = 0;     // profit maximal lorsque la tendance identique : U0, U1, U2

input int numberBot = 20230407;  // identifiant du robot à modifier si marche en double
input int sessionTradeMax = 1;   // nombre de trade maximum pour un bot
input int stopLostVal = 8;       // nombre de point sl
input int moveStopLostValx = 10; // ajout de la marge du sl
input int profitTarget = 40;     // profit maximal pour declanche le breakevent
input double lotSize = 1;        // lot correspondant à 1 EUR par point pour DJ30, DAX, NAS100

input int hourStartTrade = 9; // heure de debut de trade
input int hourEndTrade = 22;  // heure de fin de trade

bool priceAboveCloud = false;
bool priceLowCloud = false;
string message = "RECHERCHE";

// Variables globales pour stocker les valeurs précédentes de priceAboveCloud et priceLowCloud
bool previousPriceAboveCloud = false;
bool previousPriceLowCloud = false;
int sizeEssouflement = 3;

// gestion management money
double objectifProfitByDay = 180.0; // Montant de la journee à ne pas perdre si atteint depuis le portefeuil
double objectifLostByDay = -75.0;   // objectif de perte maximal par jour du portefeuil
double closeToProfit = 0;           // montant maximal à atteindre pour fermer le trade
double lostTarget = -20.0;          // fermeture du trade si perte maximal
double lotSizeRisk = 2;
int lostByTradeMax = 4;             // nombre de perte par session de trade ou jour
int moveStopLostVal = 5;            // ajout de la marge du sl
double cassureFrancheVal = 0;       // definition de la val pour determiner si cassure francge
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

  double ChinkouSpan = Ichimoku.ChinkouSpan(1);

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

  bool tenkanPriceCrossAbove = tenkanPriceCrossing(false);
  bool tenkanPriceCrossLow = tenkanPriceCrossing(true);
  bool kinjunPriceCrossAbove = kinjunPriceCrossing(false);
  bool kinjunPriceCrossLow = kinjunPriceCrossing(true);
  // int tekanCrossKinjunDirectionVal = tekanCrossKinjunDirection();

  bool bearishCoLorCandlex = bearishCoLorCandle();
  bool tekanCrossKinjunx = tekanCrossinjun();

  bool isTimeToTradeVal = isTimeToTrade();
  bool chikouIsFreexBuy = chikouIsFree(1);
  bool chikouIsFreexSell = chikouIsFree(2);
  double valGetTotalProfitToday = GetTotalProfitToday();
  // int tekanDirectionVal = tekanDirection();
  int totalPositions = PositionsTotal();

  // conditions de fermeture de trade
  bool isCloseBuy = tekanCrossKinjunx || ((kinjunPriceCrossAbove || kinjunPriceCrossLow) && bearishCoLorCandlex);
  bool isCloseSell = tekanCrossKinjunx || ((kinjunPriceCrossAbove || kinjunPriceCrossLow) && !bearishCoLorCandlex);

  // verfication de sortie si deux bougies baissier
  // ou casure de kinjun par bougie rouge
  if (totalPositions > 0 && priceAboveCloud && isCloseBuy)
  {
    closeTrade(priceAboveCloud);
    message = "CLOSE TRADE ABOVE";
  }
  // cassure kinjun par une bougie verte
  if (totalPositions > 0 && priceLowCloud && isCloseSell)
  {
    closeTrade(!priceLowCloud);
    message = "CLOSE TRADE LOW";
  }

  // initialisation si une nouvel timing
  if (!isTimeToTradeVal)
  {
    calculRisk();
  }

  // maj de l'essouflement d'un mouvement tekan casse par la bougie au sens du marche
  Essouflement(priceAboveCloud, priceLowCloud, priceInCloud, tenkanPriceCrossAbove, tenkanPriceCrossLow, bearishCoLorCandlex);

  if ((isTimeToTradeVal &&
       (valGetTotalProfitToday == 0 || objectifLostByDay < valGetTotalProfitToday)) &&
      (valGetTotalProfitToday < objectifProfitByDay) && !priceInCloud && lostByTradeMax > 0)
  {

    // verification si le prix n'es pas dans le nuage
    bool checkAddTrade = checkAddTrade();
    if (priceAboveCloud &&
        chikouIsFreexBuy &&
        tekanAboveKinjunx &&
        (tenkanPriceCrossAbove || kinjunPriceCrossAbove) &&
        bearishCoLorCandlex &&
        sizeEssouflement > 0 &&
        // sameDirectionUTendaneVal > 0 &&
        !tekanCrossKinjunx &&
        !isCloseBuy &&
        // tekanDirectionVal == 2 &&
        checkAddTrade)
    {
      addTrade();
      message = "ACHAT";
    }

    if (priceLowCloud &&
        chikouIsFreexSell &&
        tekanLowKinjunx &&
        (tenkanPriceCrossLow || kinjunPriceCrossLow) &&
        !bearishCoLorCandlex &&
        sizeEssouflement > 0 &&
        // sameDirectionUTendaneVal > 0 &&
        !tekanCrossKinjunx &&
        !isCloseSell &&
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
          "message : ", message, "\n",
          "PnL : ", valGetTotalProfitToday, "\n",
          "lostByTradeMax : ", lostByTradeMax, "\n",
          "objectifProfitByDay : ", objectifProfitByDay, "\n",
          "objectifLostByDay : ", objectifLostByDay, "\n",
          "sameDirectionUTendaneVal U0+U1+U2 : ", sameDirectionUTendaneVal, "\n",
          "uTimeTendanceCurrentVal : ", uTimeTendanceCurrentVal, "\n",
          "uTimeTendanceMidVal : ", uTimeTendanceMidVal, "\n",
          "uTimeTendanceLowVal : ", uTimeTendanceLowVal, "\n",
          // "tekanCrossKinjunDirectionVal : ", tekanCrossKinjunDirectionVal, "\n",
          // "DESSOUS : ", priceLowCloud, "\n",
          // "TEKAN CROSS PRICE : ", tenkanPriceCross, "\n",
          // "KINJUN CROSS PRICE : ", kinjunPriceCross, "\n",
          "tekanAboveKinjunx : ", tekanAboveKinjunx, "\n",
          "tekanLowKinjunx : ", tekanLowKinjunx, "\n",
          "sizeEssouflement : ", sizeEssouflement, "\n",
          // "2 PRICE LOW TEKAN : ", tekanLowLast2Price, "\n",
          // "TEKAN DIRECTION : ", tekanDirectionVal, "\n",
          "ChinkouSpan : ", ChinkouSpan, "\n",
          "2 PRICE ABOVE TEKAN : ", tekanAboveLast2PriceCross, "\n",
          "TEKAN CROSS KINJUN : ", tekanCrossKinjunx, "\n");
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
  //--
}

//+------------------------------------------------------------------+

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
    sizeEssouflement = 3;
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
    calculRisk(riskLostHigh, profitHigh, riskLotHigh, 20);
    sameDirectionUTendane = 4;
  }
  else
  {
    calculRisk(riskLostHigh, profitMini, riskLotMini, 10);
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
void calculRisk(double lostTargetVal = -30, double closeToProfitVal = 0, double lotSizeRiskVal = 1, int moveStopLostValParam = 20)
{
  double capital = AccountInfoDouble(ACCOUNT_BALANCE);
  objectifProfitByDay = (capital * percentProfit) * 4;
  objectifLostByDay = (capital * percentRisk) * 15;
  lostTarget = lostTargetVal;       // capital * percentRisk;
  closeToProfit = closeToProfitVal; // capital * percentProfit;
  lotSizeRisk = lotSizeRiskVal;
  moveStopLostVal = moveStopLostValParam;
  lostByTradeMax = 124;
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

// retourne true si le prix est dans le nuage
bool priceInCloud()
{
  double SpanAx1 = Ichimoku.SenkouSpanA(1);
  double SpanBx1 = Ichimoku.SenkouSpanB(1);

  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);
  bool isRange = last_close < SpanAx1 && last_open < SpanAx1 && last_close > SpanBx1 && last_open > SpanBx1;
  return isRange;
}
// le prix à la baisse croise la tenkan
// il faut que le prix d'ouverture & fermture est une differencte d'au moins 5
bool tenkanPriceCrossing(bool isAboveLow)
{
  double TenkanVal = Ichimoku.TenkanSen(1);
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);
  bool isCassureFranche = false;

  // verfication cassure franche avec un pips definit : vente
  if (isAboveLow)
  {
    isCassureFranche = (TenkanVal - last_open) > cassureFrancheVal && (last_close - TenkanVal) > cassureFrancheVal;
  }
  else
  {
    isCassureFranche = (last_open - TenkanVal) > cassureFrancheVal && (TenkanVal - last_close) > cassureFrancheVal;
  }

  bool tenkanPriceCross = (last_open > TenkanVal && last_close < TenkanVal) ||
                          (last_open < TenkanVal && last_close > TenkanVal);
  return tenkanPriceCross; // && isCassureFranche;
}

// le prix croise la kinjun
bool kinjunPriceCrossing(bool isAboveLow)
{
  double KijunVal = Ichimoku.KijunSen(1);
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);
  bool isCassureFranche = false;

  // verfication cassure franche avec un pips definit : vente
  if (isAboveLow)
  {
    isCassureFranche = ((KijunVal - last_open) > cassureFrancheVal) && ((last_close - KijunVal) > cassureFrancheVal);
  }
  else
  {
    isCassureFranche = ((last_open - KijunVal) > cassureFrancheVal) && ((KijunVal - last_close) > cassureFrancheVal);
  }

  bool kinjunPriceCross = (last_open > KijunVal && last_close < KijunVal) || (last_open < KijunVal && last_close > KijunVal);
  return kinjunPriceCross; // && isCassureFranche;
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
  bool valTekanLowKinjun = TenkanVal > KijunVal;
  return valTekanLowKinjun;
}

// verifie que la tenkan est en dessous
bool tekanLowKinjun()
{
  double TenkanVal = Ichimoku.TenkanSen(1);
  double KijunVal = Ichimoku.KijunSen(1);
  bool valTekanLowKinjun = TenkanVal < KijunVal;
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
// verifier si bougie rouge = true ou verte = false
bool bearishCoLorCandle()
{
  // Obtenir les prix de clôture et d'ouverture de la bougie précédente
  double last_close = iClose(Symbol(), 0, 1);
  double last_open = iOpen(Symbol(), 0, 1);

  // Vérifier si la bougie précédente est haussière
  bool bullishCandle = last_close > last_open;

  // Retourner true si la bougie précédente est haussière, sinon false
  return bullishCandle;
}

// ajout du stoplost en dessous de la bougie qui a casse une des droites
// je recupere le prix le plus bas si c'est un achat et le plus haut si c'est une vente
double addStopLostByCandle(int positionCandle = 2, double margeSL = 0)
{
  double slost = 0;
  bool bearishCoLorCandlex = bearishCoLorCandle();
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
  if (totalPositions < sessionTradeMax)
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

      // lostByTradeMax--;
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

// verifier si il atteint closeToProfit pour la premier fois
// et mettre le stop lost à la bougie au dessus de la bougie precedente
double addSlSecureByCandle()
{
  isAddSlSecureByCandle = true;
  double valAddStopLost = addStopLostByCandle(0, 1);
  Print("SL SECURE : ", valAddStopLost);
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

  bool bearishCoLorCandlex = bearishCoLorCandle();
  if (bearishCoLorCandlex)
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

// la chikou est libre de tendance et n'a pas d'obstacle devant lui (soit 10 bougie)
// verifier si la 26eme bougie en arriere croise la chekou
// verifier si la chekou se trouve dans le nuage
// NB : si achat on prend le prix de fermeture & on verfie si la 26eme bougie en arriere
// peut contenir le en fonction de son plus haut & plus bas le prix de la fermeture
bool chikouIsFree(int typeOrderChikou)
{
  bool isChikouAboveLowCloud = false;
  bool isChikouObstacle = true;
  int nbCandles = 26;
  // joue le role de la chikou
  double current_price = iClose(Symbol(), 0, 1);
  double SpanAx1 = Ichimoku.SenkouSpanA(26);
  double SpanBx1 = Ichimoku.SenkouSpanB(26);

  // si achat
  if (typeOrderChikou == 1)
  {
    isChikouAboveLowCloud = current_price > SpanAx1 && current_price > SpanBx1;
    // obstacle devant la chikou verifie si le high de la bougie soit inferieur au prix de la chikou
    // obstacle à la chikou sur 5 bougie
    for (int nbCandle = nbCandles; nbCandle >= 16; nbCandle--)
    {
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
    isChikouAboveLowCloud = current_price < SpanAx1 && current_price < SpanBx1;
    for (int nbCandle = nbCandles; nbCandle >= 16; nbCandle--)
    {
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
  //  Retourner true si le prix de la Chikou-sen est compris entre les prix d'ouverture et de clôture de la 26ème barre en arrière, sinon false
  return isChikouAboveLowCloud && isChikouObstacle;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
