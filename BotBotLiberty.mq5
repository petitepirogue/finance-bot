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
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Indicators/Trend.mqh>
CiIchimoku *Ichimoku;

//+------------------------------------------------------------------+
//| Paramètre d'entrée du robot                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input double profitTarget = 10.0; // permet de declacher le breakevent pour securiser le trade (stoplos)
input double lostTarget = -30.0;  // objectif PERTE maximal de gain
input int numberBot = 20230406;   // pour identifier le bot à modifier cela doit etre unique
input int mmLent = 7;             // Moyenne mobile Rapide
input int mmRapide = 20;          // Moyenne mobile Lente
input double lotSize = 1;         // valeur en point 1(EUR) adapter pour GER40, DJ30 & NAS100
input int sessionTradeMax = 1;    // nombre du bot de trade maximal par session
input int hourStartTrade = 9;     // heure de debut de trade
input int hourEndTrade = 22;      // heure de fin de trade
input int profitTargetLent = 30;  // permet de mettre le sl serre sur MM7
//+------------------------------------------------------------------+
//| Création des variables du robots                                 |
//+------------------------------------------------------------------+
#define EXPERT_MAGIC numberBot; // utilisation de la technique de tradosaure

// Liste des positions atteignant l'objectif de profit
CArrayObj positionsReachedTarget;
CTrade TradeManager;       // objet pour la gestion du trade
int currentTypeTrade = 0;  // 1 achat, 2 vente
CArrayInt responseRevange; // liste des trade revange
bool priceAboveCloud = false;
bool priceLowCloud = false;
bool furureCloudGreen = false;
bool furureCloudRed = false;

//+------------------------------------------------------------------+
//| Expert initialization function lors de la modification du système|
//| temps, indicateurs & vars du marche ou ajout d'un event                              |
//+------------------------------------------------------------------+
int OnInit()
{
  Ichimoku = new CiIchimoku();
  Ichimoku.Create(_Symbol, PERIOD_CURRENT, 9, 26, 52);
  responseRevange = new CArrayObj(); // Initialisation de la liste dynamique
                                     // ArraySetAsSeries(SenkouSpanA, true);
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
  bool isTimeToTradeVal = isTimeToTrade();
  if (isTimeToTradeVal)
  {
    crossingMM(mmLent, mmRapide);
  }
  moveStopLost();
  acceptAmountLostTrade();
  isSpanHorizontal();
  // fermeture du trade par cloture de bougie
  closeByBougieMM();
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

// verifier avant de rentrer dans un trade que le prix ne se trouve pas dans le nuage entre span a & span b
// fermeture du trade si une bougie se trouve en dessous d'une moyenne mobile definie
void closeByBougieMM(int mm = 20)
{
  // Récupérer le prix de clôture de la dernière bougie
  double last_close = iClose(Symbol(), 0, 1);
  // Récupérer le prix d'ouverture de la dernière bougie
  double last_open = iOpen(Symbol(), 0, 1);

  // Tableau pour stocker les valeurs de la moyenne mobile 20
  double myMovingAverageArray[];
  int mm20_handle = iMA(NULL, 0, mm, 0, MODE_SMA, PRICE_CLOSE);
  ArraySetAsSeries(myMovingAverageArray, true);
  CopyBuffer(mm20_handle, 0, 0, 3, myMovingAverageArray);

  // Vérifier si le prix de clôture et d'ouverture de la dernière bougie sont en dessous de la moyenne mobile 20
  // si je suis en dessous et que je suis en achat je ferme
  if (last_close < myMovingAverageArray[0] && last_open < myMovingAverageArray[0])
  {
    if (currentTypeTrade == 1)
    {
      closeTrade();
      // Comment("DESSOUS : ", myMovingAverageArray[0]);
    }
  }
  // Vérifier si la bougie se situe sur la droite
  else if (last_close > myMovingAverageArray[0] && last_open > myMovingAverageArray[0])
  {
    if (currentTypeTrade == 2)
    {
      closeTrade();
      // Comment("DESSUS", myMovingAverageArray[0]);
    }
  }
}
// verification ex. si la MM7 & MM20 se croise
// verifie si la position des MM sont en dessous ou dessus de l'axe des ordonnees en params
// au dessus/dessous de l'axe des ordonées au moins avec une distance definie
// si 1 achat, si 2 vente sinon rien 0
int crossingMM(int mm7 = 7, int mm20 = 20)
{

  double myMovingAverrageArray1[], myMovingAverrageArray2[];

  int mm7_value = iMA(NULL, 0, mm7, 0, MODE_SMA, PRICE_CLOSE);   // Valeur de la moyenne mobile 7
  int mm20_value = iMA(NULL, 0, mm20, 0, MODE_SMA, PRICE_CLOSE); // Valeur de la moyenne mobile 20

  ArraySetAsSeries(myMovingAverrageArray1, true);
  ArraySetAsSeries(myMovingAverrageArray2, true);

  CopyBuffer(mm7_value, 0, 0, 3, myMovingAverrageArray1);
  CopyBuffer(mm20_value, 0, 0, 3, myMovingAverrageArray2);

  bool checkAddTrade = checkAddTrade();

  int totalPositions = PositionsTotal(); // Obtenir le nombre total de positions ouvertes
  if ((myMovingAverrageArray1[0] > myMovingAverrageArray2[0]) &&
      (myMovingAverrageArray1[1] < myMovingAverrageArray2[1]))
  {
    // fermeture des trades en vente
    if (checkAddTrade && (currentTypeTrade == 2 || currentTypeTrade == 0))
    {
      closeTrade();
    }
    if (checkAddTrade && (currentTypeTrade == 2 || currentTypeTrade == 0))
    {
      addTrade();
      currentTypeTrade = 1;
      return currentTypeTrade;
    }

    // Comment("BUY");
  }

  if ((myMovingAverrageArray1[0] < myMovingAverrageArray2[0]) &&
      (myMovingAverrageArray1[1] > myMovingAverrageArray2[1]))
  {
    // fermeture des trades en achat
    if (checkAddTrade && currentTypeTrade == 1 || currentTypeTrade == 0)
    {
      closeTrade(false);
    }

    if (checkAddTrade && (currentTypeTrade == 1 || currentTypeTrade == 0))
    {
      addTrade(false);
      currentTypeTrade = 2;
      return currentTypeTrade;
    }

    // Comment("SELL");
  }

  return 0;
}

//+-----------------------------------------------------------------------------+
//| verifer si le nuage span a ou span b sont horizontal en partant des bougies |
//+-----------------------------------------------------------------------------+
bool isSpanHorizontal()
{
  Ichimoku.Refresh(-1);
  double TenkanVal = Ichimoku.TenkanSen(1);
  double KijunVal = Ichimoku.KijunSen(1);
  double ChikouVal = Ichimoku.ChinkouSpan(26);

  double SpanAx1 = Ichimoku.SenkouSpanA(1);
  double SpanAx2 = Ichimoku.SenkouSpanA(2);
  double SpanAx26 = Ichimoku.SenkouSpanA(26);
  double SpanAxf26 = Ichimoku.SenkouSpanA(-26);

  double SpanBx1 = Ichimoku.SenkouSpanB(1);
  double SpanBx2 = Ichimoku.SenkouSpanB(2);
  double SpanBx26 = Ichimoku.SenkouSpanB(26);
  double SpanBxf26 = Ichimoku.SenkouSpanB(-26);

  // Récupérer le prix de clôture de la dernière bougie
  double close1 = iClose(Symbol(), 0, 1);
  double close2 = iClose(Symbol(), 0, 2);

  // Récupérer le prix de clôture de la dernière bougie
  double last_close = iClose(Symbol(), 0, 1);
  // Récupérer le prix d'ouverture de la dernière bougie
  double last_open = iOpen(Symbol(), 0, 1);

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

  bool isRange = false;
  string messages = "";
  if (last_close < SpanAx1 && last_open < SpanAx1 && last_close > SpanBx1 && last_open > SpanBx1)
  {
    isRange = true;
    messages = "RANGE NUAGE";
  }

  // Vérifier si le prix d'ouverture et de clôture de la dernière bougie sont compris entre Span A et Span B
  if (priceAboveCloud && !isRange)
  {
    messages = "DESSUS NUAGE";
  }
  else if (priceLowCloud && !isRange)
  {
    messages = "DESSOUS NUAGE";
  }
  else
  {
    //
  }

  Comment(messages, "\n",
          "last_close: ", last_close, "\n",
          "last_open: ", last_open, "\n",
          "Tenkan Sen Value is: ", TenkanVal, "\n",
          "Kijun Sen Value is: ", KijunVal, "\n",
          "Chikou Span Value is: ", ChikouVal, "\n",
          "Senkou Span A Value is: ", SpanAx1, "\n",
          "Senkou Span B Value is: ", SpanBx1, "\n",
          "Senkou Span Af Value is: ", SpanAxf26, "\n",
          "Senkou Span Bf Value is: ", SpanBxf26, "\n");

  return isRange;
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
// Définir la variable pour le profit cible
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
    ulong position_ticket = PositionGetTicket(i);                        // ticket de la position
    string position_symbol = PositionGetString(POSITION_SYMBOL);         // symbole
    int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS); // nombre de décimales
    double sl = PositionGetDouble(POSITION_SL);                          // Stop Loss de la position
    double tp = PositionGetDouble(POSITION_TP);                          // Take Profit de la position
    double currentProfit = PositionGetDouble(POSITION_PROFIT);           // Profit actuel de la position
    ulong magic = PositionGetInteger(POSITION_MAGIC);

    //--- si le Stop Loss et le Take Profit ne sont pas définis
    if (magic == numberBot && currentProfit >= profitTarget)
    {
      // Calculer le niveau du stop loss à partir de mmLent ou mmRapide
      double addStopLostVal = currentProfit > profitTargetLent ? mmLent : mmRapide;
      double stopLossLevel = addStopLost(addStopLostVal);

      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
        // stopLossLevel = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + stopLossDistance, digits);
        if (addStopLostVal == mmLent)
        {
          stopLossLevel = stopLossLevel - 5;
        }
        stopLossLevel = stopLossLevel - 5;
      }

      else
      {
        // stopLossLevel = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - stopLossDistance, digits);
        if (addStopLostVal == mmLent)
        {
          stopLossLevel = stopLossLevel + 5;
        }
        stopLossLevel = stopLossLevel + 5;
      }

      //--- remise à zéro de la demande et du résultat
      ZeroMemory(request);
      ZeroMemory(result);

      //--- définition des paramètres de l'opération
      request.action = TRADE_ACTION_SLTP; // type de l'opération de trading
      request.position = position_ticket; // ticket de la position
      request.symbol = position_symbol;   // symbole
      request.sl = stopLossLevel;         // Stop Loss de la position
      request.magic = EXPERT_MAGIC;       // MagicNumber de la position

      //--- affiche des informations sur la modification
      PrintFormat("Modification de #%I64d %s", position_ticket, position_symbol);

      //--- envoi de la demande
      if (!OrderSend(request, result))
        PrintFormat("OrderSend erreur %d", GetLastError()); // en cas d'échec de l'envoi, affiche le code de l'erreur
    }
  }
}

// fermetue du trade du current trade
void acceptAmountLostTrade()
{
  // Comment("CLOSE TRADES");
  //--- déclare et initialise la demande de trading et le résultat
  MqlTradeRequest request;
  MqlTradeResult result;
  int total = PositionsTotal(); // nombre de positions ouvertes
                                // liste des trades pour la revange si stoplost
  responseRevange.Clear();      // Réinitialise la liste
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
    //--- si le MagicNumber correspond
    // if((magic == EXPERT_MAGIC) // pour supprimer uniquement ceux du nombre magic
    if (lostTarget >= currentProfit && magic == numberBot)
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
      if (currentTypeTrade == 1)
      {
        request.price = SymbolInfoDouble(position_symbol, SYMBOL_BID);
        request.type = ORDER_TYPE_SELL;
        // TODO verif si c'est le sens du marche RENTREE EN ACHAT REVENGE
        // addTrade(false);
        responseRevange.Add(1);
        // Comment("REVENGE ACHAT");
      }
      else
      {
        request.price = SymbolInfoDouble(position_symbol, SYMBOL_ASK);
        request.type = ORDER_TYPE_BUY;
        // TODO verif si c'est le sens du marche RENTREE EN vente REVENGE
        // addTrade();
        responseRevange.Add(2);
        // Comment("REVENGE VENTE");
      }
      //--- affiche les informations de clôture
      PrintFormat("acceptAmountLostTrade #%I64d %s %s", position_ticket, position_symbol, EnumToString(type));
      //--- envoi la demande
      if (!OrderSend(request, result))
        Comment("acceptAmountLostTrade Send erreur %d", GetLastError()); // en cas d'échec de l'envoi, affiche le code d'erreur
                                                                         //--- informations sur l'opération
                                                                         // PrintFormat("retcode=%u  transaction=%I64u  ordre=%I64u",result.retcode,result.deal,result.order);
                                                                         //---
    }
  }
}

// fermetue du trade du current trade
void closeTrade(bool isBuyOrSell = true)
{
  // Comment("CLOSE TRADES");
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
    //--- si le MagicNumber correspond
    if (magic == numberBot) // pour supprimer uniquement ceux du nombre magic
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
      request.magic = EXPERT_MAGIC;       // MagicNumber de la position
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
  /// verifie avant de rentrer dans le marché que c'est pas range dans le nuage'
  bool isRange = isSpanHorizontal();
  if (true)
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
    double price_level = profitTarget;
    //--- calcul et arrondi des valeurs du Stop Loss et du Take Profit
    // price_level=stop_level*SymbolInfoDouble(position_symbol,SYMBOL_POINT);
    // ajouter le sl en fonction de la position de la droite mm20
    double valAddStopLost = addStopLost();
    price_level = valAddStopLost;

    if (isBuyOrSell)
    {
      // sl=NormalizeDouble(bid-price_level,digits);
      // tp=NormalizeDouble(bid+price_level,digits);
      sl = valAddStopLost - 10;
    }
    else
    {
      // sl=NormalizeDouble(ask+price_level,digits);
      // tp=NormalizeDouble(ask-price_level,digits);
      sl = valAddStopLost + 10;
    }

    //--- déclare et initialise la demande de trading et le résultat de la demande
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    //--- paramètres de la demande
    request.action = TRADE_ACTION_DEAL; // type de l'opération de trading
    request.symbol = Symbol();          // symbole
    request.sl = sl;                    // stoplost
    // request.tp       = tp;                            // take profit
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
      Comment("Add TRADE OrderSend erreur %d", GetLastError());
    }
    //--- informations de l'opération
    // Comment("retcode=%u  transaction=%I64u  ordre=%I64u",result.retcode,result.deal,result.order);
  }
}

// ajout d'un stop lost au trade à la session en cours sur la mm20 5 points en arriere
double addStopLost(int mm20 = 20)
{
  double myMovingAverrageArray1[];
  int mm20_value = iMA(NULL, 0, mm20, 0, MODE_SMA, PRICE_CLOSE);
  ArraySetAsSeries(myMovingAverrageArray1, true);
  CopyBuffer(mm20_value, 0, 0, 3, myMovingAverrageArray1);
  return myMovingAverrageArray1[0];
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
// permet de verifier l'heure de trade'
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

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
