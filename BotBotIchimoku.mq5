//+------------------------------------------------------------------+
//|                                        BotBotIchimokuLiberty.mq5 |
//|                                        Copyright 2024, GenixCode |
//|                                        https://www.genixcode.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, GenixCode"
#property link      "https://www.genixcode.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Indicators/Trend.mqh>

CiIchimoku*Ichimoku;
CiIchimoku*Ichimoku_1;
CiIchimoku*Ichimoku_2;

input int numberBot = 20230407; // identifiant du robot à modifier si marche en double
input double lotSize = 10; // lot correspondant à 1 EUR par point pour DJ30, DAX, NAS100
input int sessionTradeMax = 1; // nombre de trade maximum pour un bot
input int stopLostVal = 10; // nombre de point sl pour ajouter à MM20
input int profitTarget = 10; // profit maximal pour declanche le breakevent
input int hourStartTrade = 9; // heure de debut de trade
input int hourEndTrade = 22; // heure de fin de trade

int uTime_1 = 0;
int uTime_2 = 0;
bool priceAboveCloud = false;
bool priceLowCloud = false;
string message = "RECHERCHE";

#define EXPERT_MAGIC numberBot;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Ichimoku = new CiIchimoku();
   Ichimoku.Create(_Symbol,PERIOD_CURRENT,9,26,52);

   Ichimoku_1 = new CiIchimoku();
   Ichimoku_1.Create(_Symbol,PERIOD_M15,9,26,52);

   Ichimoku_2 = new CiIchimoku();
   Ichimoku_2.Create(_Symbol,PERIOD_H1,9,26,52);

   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//regarde sur les unites de temps profond
   uTime_1 = uTimeMiddle();

   moveStopLost();
   Ichimoku.Refresh(-1);
   bool priceInCloud = priceInCloud();
   bool tekanAboveLast2PriceCross = tekanAboveLast2PriceCrossing();
   bool tekanLowLast2Price = tekanLowLast2PriceCrossing();

   aboveLowCloud();
   bool tekanLowKinjunx = tekanLowKinjun();
   bool tekanAboveKinjunx = tekanAboveKinjun();
   bool tenkanPriceCross = tenkanPriceCrossing();
   bool bearishCoLorCandlex = bearishCoLorCandle();
   bool tekanCrossinjunx = tekanCrossinjun();
   bool kinjunPriceCross = kinjunPriceCrossing();
   bool chikouIsFreex = chikouIsFree();
   bool isTimeToTradeVal = isTimeToTrade();

// verfication de sortie si deux bougies baissier
   if(priceAboveCloud && tekanLowLast2Price)
     {
      closeTrade();
      message = "CLOSE TRADE ABOVE";
     }

   if(priceLowCloud && tekanAboveLast2PriceCross)
     {
      closeTrade(false);
      message = "CLOSE TRADE LOW";
     }

// verification si le prix n'es pas dans le nuage
   if(isTimeToTradeVal && !priceInCloud)
     {
      bool checkAddTrade = checkAddTrade();
      if(priceAboveCloud && tekanAboveKinjunx && tenkanPriceCross && bearishCoLorCandlex && checkAddTrade)
        {
         addTrade();
         message = "ACHAT";
        }

      if(priceLowCloud && tekanLowKinjunx && tenkanPriceCross && !bearishCoLorCandlex && checkAddTrade)
        {
         addTrade(false);
         message = "VENTE";
        }
     }

   double TenkanVal= Ichimoku.TenkanSen(1);
   int totalPositions = PositionsTotal();
   datetime current_time = TimeCurrent();

   Comment("HEURE DE TRADE: ",isTimeToTradeVal, " : ", TimeToString(current_time, TIME_DATE | TIME_MINUTES),"\n",
           "ACTION : ", message, "\n",
           "POSITION : ", totalPositions, "\n",
           "RANGE : ", priceInCloud, "\n",
           "UT MIDDLE : ", uTime_1, "\n",
           "UT LOW : ", uTime_2, "\n",
           "TEKAN : ", TenkanVal,"\n",
           "DESSUS : ", priceAboveCloud, "\n",
           "DESSOUS : ", priceLowCloud, "\n",
           "TEKAN CROSS PRICE : ", tenkanPriceCross, "\n",
           "KINJUN CROSS PRICE : ", kinjunPriceCross, "\n",
           "TEKAN ABOVE KINJUN : ", tekanAboveKinjunx, "\n",
           "TEKAN LOW KINJUN : ", tekanLowKinjunx, "\n",
           "2 PRICE LOW TEKAN : ", tekanLowLast2Price, "\n",
           "PRICE BUY/SELL : ", bearishCoLorCandlex, "\n",
           "2 PRICE ABOVE TEKAN : ", tekanAboveLast2PriceCross, "\n",
           "TEKAN CROSS KINJUN : ", tekanCrossinjunx, "\n",
           "CHIKOU IS FREE : ", chikouIsFreex, "\n");
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//--

  }
//+------------------------------------------------------------------+

// verifie si le prix se situe en dessous ou au dessus du nuage SI TRUE au dessus du nuage
void aboveLowCloud()
  {
   Ichimoku.Refresh(-1);
   double TenkanVal= Ichimoku.TenkanSen(1);
   double KijunVal= Ichimoku.KijunSen(1);
   double ChikouVal= Ichimoku.ChinkouSpan(26);

   double SpanAx1= Ichimoku.SenkouSpanA(1);
   double SpanAx2= Ichimoku.SenkouSpanA(2);

   double SpanBx1= Ichimoku.SenkouSpanB(1);
   double SpanBx2= Ichimoku.SenkouSpanB(2);

// Récupérer le prix de clôture de la dernière bougie
   double close1 = iClose(Symbol(), 0, 1);
   double close2 = iClose(Symbol(), 0, 2);

// le prix est au dessus des nuages
   if(!priceAboveCloud && (close2 < SpanAx2 || close2 < SpanBx2) && close1 > SpanAx1 && close1 > SpanBx1)
     {
      priceAboveCloud = true;
      priceLowCloud = false;
     }

   if(!priceLowCloud && (close2 > SpanAx2 || close2 > SpanBx2) && close1 < SpanAx1 && close1 < SpanBx1)
     {
      priceAboveCloud = false;
      priceLowCloud = true;
     }
  }
//+------------------------------------------------------------------+

// retourne true si le prix est dans le nuage
bool priceInCloud()
  {
   Ichimoku.Refresh(-1);
   double SpanAx1= Ichimoku.SenkouSpanA(1);
   double SpanBx1= Ichimoku.SenkouSpanB(1);

   double last_close = iClose(Symbol(), 0, 1);
   double last_open = iOpen(Symbol(), 0, 1);
   bool isRange = last_close < SpanAx1 && last_open < SpanAx1 && last_close > SpanBx1 && last_open > SpanBx1;
   return isRange;
  }
// le prix à la baisse croise la tenkan
bool tenkanPriceCrossing()
  {
   Ichimoku.Refresh(-1);
   double TenkanVal= Ichimoku.TenkanSen(1);
   double last_close = iClose(Symbol(), 0, 1);
   double last_open = iOpen(Symbol(), 0, 1);
   bool tenkanPriceCross = (last_open > TenkanVal && last_close < TenkanVal) || (last_open < TenkanVal && last_close > TenkanVal);
   return tenkanPriceCross;
  }

// le prix à la baisse croise la tenkan
bool kinjunPriceCrossing()
  {
   Ichimoku.Refresh(-1);
   double KijunVal= Ichimoku.KijunSen(1);
   double last_close = iClose(Symbol(), 0, 1);
   double last_open = iOpen(Symbol(), 0, 1);

   bool kinjunPriceCross = (last_open > KijunVal && last_close < KijunVal) || (last_open < KijunVal && last_close > KijunVal);
   return kinjunPriceCross;
  }
//verifier si la tenkan est au dessus des prix
bool tekanAboveLast2PriceCrossing()
  {
   Ichimoku.Refresh(-1);
   double TenkanVal= Ichimoku.TenkanSen(1);
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
   Ichimoku.Refresh(-1);
   double TenkanVal= Ichimoku.TenkanSen(1);
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
   Ichimoku.Refresh(-1);
   double TenkanVal= Ichimoku.TenkanSen(1);
   double KijunVal= Ichimoku.KijunSen(1);
   bool valTekanLowKinjun = TenkanVal > KijunVal;
   return valTekanLowKinjun;
  }

// verifie que la tenkan est en dessous
bool tekanLowKinjun()
  {
   Ichimoku.Refresh(-1);
   double TenkanVal= Ichimoku.TenkanSen(1);
   double KijunVal= Ichimoku.KijunSen(1);
   bool valTekanLowKinjun = TenkanVal < KijunVal;
   return valTekanLowKinjun;
  }
// verifie si la tenkan croise la kinjun
bool tekanCrossinjun()
  {
// Actualiser l'indicateur Ichimoku
   Ichimoku.Refresh(-1);

// Obtenir les valeurs actuelles de la Tenkan-sen et de la Kijun-sen
   double TenkanVal = Ichimoku.TenkanSen(1);
   double KijunVal = Ichimoku.KijunSen(1);

// Obtenir les valeurs précédentes de la Tenkan-sen et de la Kijun-sen
   double TenkanValPrev = Ichimoku.TenkanSen(2);
   double KijunValPrev = Ichimoku.KijunSen(2);

// Vérifier si la Tenkan-sen croise la Kijun-sen
   bool tenkanCrossesKijun = (TenkanValPrev < KijunValPrev && TenkanVal > KijunVal) || (TenkanValPrev > KijunValPrev && TenkanVal < KijunVal);

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
double addStopLostByCandle()
  {
   double slost = 0;
   bool bearishCoLorCandlex = bearishCoLorCandle();
   if(bearishCoLorCandlex)
     {
      slost = iLow(Symbol(), 0, 1);
     }
   else
     {
      slost = iHigh(Symbol(), 0, 1);
     }
   return slost;
  }

// ajout du stop lost en fonction de la position de la kinjun
double addStopLost()
  {
   Ichimoku.Refresh(-1);
   double KijunVal= Ichimoku.KijunSen(1);
   return KijunVal;
  }


// Ajout d'un trade
void addTrade(bool isBuyOrSell = true)
  {

   int totalPositions = PositionsTotal();
   if(totalPositions < sessionTradeMax)
     {
      // TODO ne pas ajouter de trade si span a & span b horizontal
      string position_symbol=PositionGetString(POSITION_SYMBOL); // symbole
      int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS); // nombre de décimales
      double price=PositionGetDouble(POSITION_PRICE_OPEN);
      double bid=SymbolInfoDouble(position_symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
      int    stop_level=(int)SymbolInfoInteger(position_symbol,SYMBOL_TRADE_STOPS_LEVEL);
      double sl=PositionGetDouble(POSITION_SL);  // Stop Loss de la position
      double tp=PositionGetDouble(POSITION_TP);  // Take Profit de la position
      //--- calcul et arrondi des valeurs du Stop Loss et du Take Profit
      // price_level=stop_level*SymbolInfoDouble(position_symbol,SYMBOL_POINT);
      // ajouter le sl en fonction de la position de la droite mm20
      // double valAddStopLost = addStopLost();
      double valAddStopLost = addStopLostByCandle();
      double price_level = valAddStopLost;

      if(isBuyOrSell)
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

      //--- déclare et initialise la demande de trading et le résultat de la demande
      MqlTradeRequest request= {};
      MqlTradeResult  result= {};
      //--- paramètres de la demande
      request.action   = TRADE_ACTION_DEAL;                // type de l'opération de trading
      request.symbol   = Symbol();                         // symbole
      request.sl       = sl;                               // stoplost
      // request.tp       = tp;                            // take profit
      request.volume   = lotSize;                          // volume de 0.1 lot
      request.type     = isBuyOrSell ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;                    // type de l'ordre
      request.price    = SymbolInfoDouble(Symbol(), isBuyOrSell ? SYMBOL_ASK : SYMBOL_BID); // prix d'ouverture
      request.deviation= 5;                                // déviation du prix autorisée
      request.magic    = EXPERT_MAGIC;                     // MagicNumber de l'ordre
      request.type_filling = ORDER_FILLING_IOC;
      //--- envoi la demande
      if(!OrderSend(request,result))
        {
         // en cas d'erreur d'envoi de la demande, affiche le code d'erreur
         Comment("Add TRADE OrderSend erreur %d",GetLastError());
        }
      //--- informations de l'opération
      // Comment("retcode=%u  transaction=%I64u  ordre=%I64u",result.retcode,result.deal,result.order);
     }
  }

// fermetue du trade du current trade
void closeTrade(bool isBuyOrSell = true)
  {
// Comment("CLOSE TRADES");
//--- déclare et initialise la demande de trading et le résultat
   MqlTradeRequest request;
   MqlTradeResult  result;
   int total=PositionsTotal(); // nombre de positions ouvertes
//--- boucle sur toutes les positions ouvertes
   for(int i=total-1; i>=0; i--)
     {
      //--- paramètres de l'ordre
      ulong  position_ticket=PositionGetTicket(i);                                      // ticket de la position
      string position_symbol=PositionGetString(POSITION_SYMBOL);                        // symbole
      int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);              // nombre de décimales
      ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // MagicNumber de la position
      double volume=PositionGetDouble(POSITION_VOLUME);                                 // volume de la position
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // type de la position
      //--- affiche les informations de la position
      PrintFormat("#%I64u %s  %s  %.2f  %s [%I64d]",
                  position_ticket,
                  position_symbol,
                  EnumToString(type),
                  volume,
                  DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),digits),
                  magic);
      //--- si le MagicNumber correspond
      if(magic == numberBot) // pour supprimer uniquement ceux du nombre magic
        {
         //--- remise à zéro de la demande et du résultat
         ZeroMemory(request);
         ZeroMemory(result);
         //--- paramètres de l'opration
         request.action   =TRADE_ACTION_DEAL;        // type de l'opération de trading
         request.position =position_ticket;          // ticket de la position
         request.symbol   =position_symbol;          // symbole
         request.volume   =volume;                   // volume de la position
         request.deviation= 5;                       // déviation du prix autoriséee
         request.magic    = numberBot;         // MagicNumber de la position
         request.type_filling = ORDER_FILLING_IOC;
         //--- définit le prix et le type de l'ordre suivant le type de la position
         if(isBuyOrSell)
           {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
            request.type =ORDER_TYPE_SELL;
           }
         else
           {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
            request.type =ORDER_TYPE_BUY;
           }
         //--- affiche les informations de clôture
         PrintFormat("Ferme #%I64d %s %s",position_ticket,position_symbol,EnumToString(type));
         //--- envoi la demande
         if(!OrderSend(request,result))
            Comment("Order close Send erreur %d",GetLastError());  // en cas d'échec de l'envoi, affiche le code d'erreur
         //--- informations sur l'opération
         // PrintFormat("retcode=%u  transaction=%I64u  ordre=%I64u",result.retcode,result.deal,result.order);
         //---
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void moveStopLost()
  {
//--- déclare et initialise la demande de trade et le résultat
   MqlTradeRequest request;
   MqlTradeResult  result;
   int total = PositionsTotal(); // nombre de positions ouvertes
   double TenkanVal= Ichimoku.TenkanSen(1);
//--- boucle sur toutes les positions ouvertes
   for(int i=0; i<total; i++)
     {
      //--- paramètres de l'ordre
      ulong  position_ticket = PositionGetTicket(i);// ticket de la position
      string position_symbol = PositionGetString(POSITION_SYMBOL); // symbole
      int    digits = (int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS); // nombre de décimales
      double sl = PositionGetDouble(POSITION_SL);  // Stop Loss de la position
      double tp = PositionGetDouble(POSITION_TP);  // Take Profit de la position
      double currentProfit = PositionGetDouble(POSITION_PROFIT); // Profit actuel de la position
      ulong  magic=PositionGetInteger(POSITION_MAGIC);

      //--- affiche quelques informations sur la position
      PrintFormat("#%I64u %s  %.2f  sl: %s  tp: %s",
                  position_ticket,
                  position_symbol,
                  currentProfit,
                  DoubleToString(sl,digits),
                  DoubleToString(tp,digits));

      //--- si le Stop Loss et le Take Profit ne sont pas définis
      if(magic == numberBot && currentProfit >= profitTarget)
        {
         double stopLossLevel = TenkanVal;

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            // stopLossLevel = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + stopLossDistance, digits);
            stopLossLevel = stopLossLevel - 10;
         else
            // stopLossLevel = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - stopLossDistance, digits);
            stopLossLevel = stopLossLevel + 10;

         //--- remise à zéro de la demande et du résultat
         ZeroMemory(request);
         ZeroMemory(result);

         //--- définition des paramètres de l'opération
         request.action = TRADE_ACTION_SLTP; // type de l'opération de trading
         request.position = position_ticket;   // ticket de la position
         request.symbol = position_symbol;     // symbole
         request.sl = stopLossLevel;           // Stop Loss de la position
         request.magic = EXPERT_MAGIC;         // MagicNumber de la position

         //--- affiche des informations sur la modification
         PrintFormat("Modification de #%I64d %s", position_ticket, position_symbol);

         //--- envoi de la demande
         if(!OrderSend(request,result))
            PrintFormat("OrderSend erreur %d", GetLastError());  // en cas d'échec de l'envoi, affiche le code de l'erreur
        }
     }
  }

// Vérifie si un nouveau trade peut être ajouté en fonction du EXPERT_MAGIC courant
bool checkAddTrade()
  {
// Récupérer le nombre de positions ouvertes
   int total = PositionsTotal();
   int positionsWithCurrentMagic = 0;

// Boucle sur toutes les positions ouvertes
   for(int i = 0; i < total; i++)
     {
      // Récupérer le numéro magique de la position
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(magic == numberBot)
        {
         positionsWithCurrentMagic++;
        }
     }
   return positionsWithCurrentMagic < sessionTradeMax;

  }

// tendance haussiere = 2, range = 1, baissiere = 0
int uTimeMiddle()
  {
   int tendanceMiddleVal = 3;
   Ichimoku_1.Refresh(-1);
   double SpanAx1= Ichimoku_1.SenkouSpanA(1);
   double SpanBx1= Ichimoku_1.SenkouSpanB(1);

   double last_close = iClose(Symbol(), 0, 1);
   double last_open = iOpen(Symbol(), 0, 1);
   bool isRange = last_close < SpanAx1 && last_open < SpanAx1 && last_close > SpanBx1 && last_open > SpanBx1;
   if(isRange)
     {
      tendanceMiddleVal = 1;
     }
   else
     {
      double TenkanVal= Ichimoku_1.TenkanSen(1);
      double KijunVal= Ichimoku_1.KijunSen(1);
      double ChikouVal= Ichimoku_1.ChinkouSpan(26);

      double SpanAx1= Ichimoku_1.SenkouSpanA(1);
      double SpanAx2= Ichimoku_1.SenkouSpanA(2);

      double SpanBx1= Ichimoku_1.SenkouSpanB(1);
      double SpanBx2= Ichimoku_1.SenkouSpanB(2);

      // Récupérer le prix de clôture de la dernière bougie
      double close1 = iClose(Symbol(), 0, 1);
      double close2 = iClose(Symbol(), 0, 2);

      // le prix est au dessus des nuages
      if(tendanceMiddleVal == 3 && (close2 < SpanAx2 || close2 < SpanBx2) && close1 > SpanAx1 && close1 > SpanBx1)
        {
         tendanceMiddleVal = 2;
        }

      if(tendanceMiddleVal == 3 && (close2 > SpanAx2 || close2 > SpanBx2) && close1 < SpanAx1 && close1 < SpanBx1)
        {
         tendanceMiddleVal = 0;
        }
     }

   return tendanceMiddleVal;
  }
// tendance haussiere = 2, range = 1, baissiere = 0
int uTimeLow()
  {
   int tendanceFontVal = 1;
   return tendanceFontVal;
  }

//+------------------------------------------------------------------+
//| ajout des herues de trading par default 9h à 22h                 |
//+------------------------------------------------------------------+
bool isTimeToTrade()
  {
   bool isTimeTOTradeVal = true;
   MqlDateTime rightNow;
   TimeToStruct(TimeCurrent(),rightNow);

// Vérifier si le jour actuel n'est pas un samedi (6) ou un dimanche (0)
   if(rightNow.hour >= hourStartTrade && rightNow.hour < hourEndTrade && rightNow.day_of_week != 6 && rightNow.day_of_week != 0)
     {
      isTimeTOTradeVal = true;
     }
   else
     {
      isTimeTOTradeVal = false;
     }
   return isTimeTOTradeVal;
  }

// la chikou est libre de tendance et n'a pas d'obstacle devant lui
// verifier si la 26eme bougie en arriere croise la chekou
// verifier si la chekou se trouve dans le nuage
bool chikouIsFree()
  {
// Actualiser l'indicateur Ichimoku
   Ichimoku.Refresh(-1);
// Obtenir le prix de clôture de la 26ème barre en arrière
   double close_26 = iClose(Symbol(), 0, 26);
// Obtenir le prix d'ouverture de la 26ème barre en arrière
   double open_26 = iOpen(Symbol(), 0, 26);
// Obtenir la valeur actuelle de la Chikou-sen
   double ChikouVal = Ichimoku.ChinkouSpan(0);

// Vérifier si le prix actuel de la Chikou-sen est compris entre les prix d'ouverture et de clôture de la 26ème barre en arrière
   bool chikouWithin26BackPrices = ChikouVal < open_26 && ChikouVal > close_26;

// Comment("CHIKOU : ",ChikouVal,"\n",
//        "CLOSE PRICE : ",close_26,"\n",
//        "OPEN PRICE : ",open_26,"\n");
// Retourner true si le prix de la Chikou-sen est compris entre les prix d'ouverture et de clôture de la 26ème barre en arrière, sinon false
   return chikouWithin26BackPrices;
  }

//+------------------------------------------------------------------+
