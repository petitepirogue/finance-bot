//+------------------------------------------------------------------+
//|                                                   BotScalper.mq5 |
//|                                        Copyright 2024, GenixCode |
//|                                        https://www.genixcode.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, GenixCode"
#property link "https://www.genixcode.com"
#property version "1.00"

#include <Trade\Trade.mqh>
#include <Indicators/Trend.mqh>

CiIchimoku *Ichimoku;

input int numberBot = 20230407;
#define EXPERT_MAGIC numberBot;

// gestion d'entree
double stopLostVal = 0;
int sessionTradeMax = 1;
double lotSizeRisk = 1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  Ichimoku = new CiIchimoku();
  Ichimoku.Create(_Symbol, PERIOD_M1, 9, 26, 52);
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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  Ichimoku.Refresh(-1);
  moveStopLost();

  bool tekanCrossKinjunx = tekanCrossinjun();
  bool tekanAboveKinjunx = tekanAboveKinjun();
  if (tekanCrossKinjunx)
  {
    int tekanAboveKinjunxVal = tekanAboveKinjunx ? 1 : 2;
    bool chikouIsFreeVal = true; // chikouIsFree(tekanAboveKinjunxVal);
    bool hasOpenPositionAtCurrentTimeVal = hasOpenPositionAtCurrentTime();
    if (chikouIsFreeVal && !hasOpenPositionAtCurrentTimeVal)
    {
      int addTradeVal = addTrade(tekanAboveKinjunx);
    }
  }
  Comment("tekanCrossKinjunx : ", tekanCrossKinjunx);
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
//|                                                                  |
//+------------------------------------------------------------------+
bool tekanAboveKinjun()
{
  double TenkanVal = Ichimoku.TenkanSen(1);
  double KijunVal = Ichimoku.KijunSen(1);
  bool valTekanLowKinjun = TenkanVal > KijunVal;
  return valTekanLowKinjun;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
  if (tenkanCrossesKijun)
  {
    stopLostVal = KijunVal;
  }
  return tenkanCrossesKijun;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int addTrade(bool isBuyOrSell = true)
{

  int isAddTrade = 0;
  int totalPositions = PositionsTotal();

  // verification de la taille de la bougie precedente
  double last_low = iLow(Symbol(), 0, 1);
  double last_high = iHigh(Symbol(), 0, 1);
  double lowHigh = MathAbs(last_high - last_low);

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

    double valAddStopLost = stopLostVal;
    if (isBuyOrSell)
    {
      // sl=NormalizeDouble(valAddStopLost - stopLostVal,digits);
      // tp=NormalizeDouble(bid+price_level,digits);
      sl = valAddStopLost - 30;
    }
    else
    {
      // sl=NormalizeDouble(valAddStopLost + stopLostVal,digits);
      // tp=NormalizeDouble(ask-price_level,digits);
      sl = valAddStopLost + 30;
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
    else
    {
      isAddTrade = 1;
      // sizeEssouflement--;
    }
  }

  return isAddTrade;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int closeTrade()
{
  int response = 0;
  MqlTradeRequest request;
  MqlTradeResult result;
  int total = PositionsTotal();
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
      //--- affiche les informations de clôture
      PrintFormat("Ferme #%I64d %s %s", position_ticket, position_symbol, EnumToString(type));
      //--- envoi la demande
      if (!OrderSend(request, result))
        Comment("Order close Send erreur %d", GetLastError());
      else
        response++;
    }
  }

  return response;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void moveStopLost()
{
  //--- déclare et initialise la demande de trade et le résultat
  MqlTradeRequest request;
  MqlTradeResult result;
  int total = PositionsTotal(); // nombre de positions ouvertes

  //--- boucle sur toutes les positions ouvertes
  for (int i = 0; i < total; i++)
  {
    //--- paramètres de l'ordre
    ulong position_ticket = PositionGetTicket(i);                // ticket de la position
    string position_symbol = PositionGetString(POSITION_SYMBOL); // symbole
    ulong magic = PositionGetInteger(POSITION_MAGIC);
    double stopLossDistance = 10;

    double stopLossLevel = Ichimoku.KijunSen(1);

    // Vérifier si le Stop Loss et le Take Profit ne sont pas définis
    if (magic == numberBot)
    {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double newStopLossLevel = currentStopLoss;

      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
        newStopLossLevel = iLow(Symbol(), 0, 0) - stopLossDistance;
      }
      else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
        newStopLossLevel = iHigh(Symbol(), 0, 0) + stopLossDistance;
      }

      // Vérifier si le nouveau stop-loss est plus favorable que l'actuel
      if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && newStopLossLevel > currentStopLoss) ||
          (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && newStopLossLevel < currentStopLoss))
      {
        //--- remise à zéro de la demande et du résultat
        ZeroMemory(request);
        ZeroMemory(result);

        //--- définition des paramètres de l'opération
        request.action = TRADE_ACTION_SLTP; // type de l'opération de trading
        request.position = position_ticket; // ticket de la position
        request.symbol = position_symbol;   // symbole
        request.sl = newStopLossLevel;      // Stop Loss de la position
        request.magic = numberBot;          // MagicNumber de la position

        //--- envoi de la demande
        if (!OrderSend(request, result))
        {
          PrintFormat("OrderSend erreur %d", GetLastError()); // en cas d'échec de l'envoi, affiche le code de l'erreur
        }
      }
    }
  }
}
//+------------------------------------------------------------------+

//+---------------------------------------------------------------------------------------+
//| gestion du filtre par la chinkou                                                      |
//|la chikou est libre de tendance et n'a pas d'obstacle devant lui (soit 10 bougie)      |
//|verifier si la 26eme bougie en arriere croise la chekou                                |
//|verifier si la chekou se trouve dans le nuage                                          |
//|NB : si achat on prend le prix de fermeture & on verfie si la 26eme bougie en arriere  |
//|peut contenir le en fonction de son plus haut & plus bas le prix de la fermeture       |
//+---------------------------------------------------------------------------------------+
bool chikouIsFree(int typeOrderChikou)
{
  bool isChikouAboveLowCloud = false;
  bool isChikouObstacle = true;
  bool isTenkanObstacle = false;
  bool isKijunSenObstacle = false;

  int nbCandles = 26;
  // joue le role de la chikou
  double current_price = iClose(Symbol(), 0, 1);

  // si achat
  if (typeOrderChikou == 1)
  {
    // obstacle devant la chikou verifie si le high de la bougie soit inferieur au prix de la chikou
    // obstacle à la chikou sur 16 bougies
    for (int nbCandle = nbCandles; nbCandle >= 16; nbCandle--)
    {
      // verifier si la kinjun ne fait pas obstacle
      double KijunSenVal = Ichimoku.KijunSen(nbCandle);
      isKijunSenObstacle = current_price > KijunSenVal && current_price > KijunSenVal;
      if (!isKijunSenObstacle)
      {
        // break;
      }
      // verifier si la tekan ne fait pas obstacle
      double TenkanSenVal = Ichimoku.TenkanSen(nbCandle);
      isTenkanObstacle = current_price > TenkanSenVal && current_price > TenkanSenVal;
      if (!isTenkanObstacle)
      {
        // break;
      }
      // verifier si en face la chikou n'a pas d'obstacle de nuage devant
      double SpanAx1 = Ichimoku.SenkouSpanA(nbCandle);
      double SpanBx1 = Ichimoku.SenkouSpanB(nbCandle);
      isChikouAboveLowCloud = current_price > SpanAx1 && current_price > SpanBx1;
      if (!isChikouAboveLowCloud)
      {
        // break;
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
    for (int nbCandle = nbCandles; nbCandle >= 20; nbCandle--)
    {
      // verifier si la kinjun ne fait pas obstacle
      double KijunSenVal = Ichimoku.KijunSen(nbCandle);
      isKijunSenObstacle = current_price > KijunSenVal && current_price > KijunSenVal;
      if (!isKijunSenObstacle)
      {
        // break;
      }
      // verifier si la tekan ne fait pas obstacle
      double TenkanSenVal = Ichimoku.TenkanSen(nbCandle);
      isTenkanObstacle = current_price > TenkanSenVal && current_price > TenkanSenVal;
      if (!isTenkanObstacle)
      {
        // break;
      }

      // verifier si en face la chikou n'a pas d'obstacle de nuage devant
      double SpanAx1 = Ichimoku.SenkouSpanA(nbCandle);
      double SpanBx1 = Ichimoku.SenkouSpanB(nbCandle);
      isChikouAboveLowCloud = current_price < SpanAx1 && current_price < SpanBx1;
      if (!isChikouAboveLowCloud)
      {
        // break;
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
  return isChikouAboveLowCloud && isChikouObstacle; // && isTenkanObstacle && isKijunSenObstacle;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasOpenPositionAtCurrentTime()
{
  MqlDateTime rightNow;
  TimeToStruct(TimeCurrent(), rightNow);

  int total = PositionsTotal();
  // Parcourir toutes les positions ouvertes
  for (int i = 0; i < total; i++)
  {
    // Obtenir le temps d'ouverture de la position
    long positionOpenTime = PositionGetInteger(POSITION_TIME);
    MqlDateTime positionOpenTimeVal;
    TimeToStruct(positionOpenTime, positionOpenTimeVal);

    // Vérifier si l'heure actuelle correspond à l'heure d'ouverture de la position
    if (rightNow.year == positionOpenTimeVal.year &&
        rightNow.mon == positionOpenTimeVal.mon &&
        rightNow.day == positionOpenTimeVal.day &&
        rightNow.hour == positionOpenTimeVal.hour &&
        rightNow.min == positionOpenTimeVal.min)
    {
      return true;
    }
  }

  return false;
}

//+------------------------------------------------------------------+
