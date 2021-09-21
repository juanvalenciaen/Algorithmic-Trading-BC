//
// EA Studio Expert Advisor
//
// Created with: Expert Advisor Studio
// Website: https://eaforexacademy.com/software/expert-advisor-studio/
//
// Copyright 2021, Forex Software Ltd.
//

#property copyright "Forex Software Ltd."
#property version   "2.14"
#property strict

static input string StrategyProperties__ = "------------"; // ------ Expert Properties ------
static input double Entry_Amount = 0.01; // Entry lots
input int Stop_Loss   = 54; // Stop Loss (pips)
input int Take_Profit = 201; // Take Profit (pips)
static input string Ind0 = "------------";// ----- Stochastic -----
input int Ind0Param0 = 19; // %K Period
input int Ind0Param1 = 2; // %D Period
input int Ind0Param2 = 2; // Slowing
input int Ind0Param3 = 20; // Level
static input string Ind1 = "------------";// ----- MACD Signal -----
input int Ind1Param0 = 9; // Fast EMA
input int Ind1Param1 = 18; // Slow EMA
input int Ind1Param2 = 3; // MACD SMA
static input string Ind2 = "------------";// ----- DeMarker -----
input int Ind2Param0 = 48; // Period
input double Ind2Param1 = 0.00; // Level
static input string Ind3 = "------------";// ----- Directional Indicators -----
input int Ind3Param0 = 36; // Period

static input string ExpertSettings__ = "------------"; // ------ Expert Settings ------
static input int Magic_Number = 59615429; // Magic Number

#define TRADE_RETRY_COUNT 4
#define TRADE_RETRY_WAIT  100
#define OP_FLAT           -1
#define OP_BUY            ORDER_TYPE_BUY
#define OP_SELL           ORDER_TYPE_SELL

// Session time is set in seconds from 00:00
int sessionSundayOpen           = 0;     // 00:00
int sessionSundayClose          = 86400; // 24:00
int sessionMondayThursdayOpen   = 0;     // 00:00
int sessionMondayThursdayClose  = 86400; // 24:00
int sessionFridayOpen           = 0;     // 00:00
int sessionFridayClose          = 86400; // 24:00
bool sessionIgnoreSunday        = false;
bool sessionCloseAtSessionClose = false;
bool sessionCloseAtFridayClose  = false;

const double sigma=0.000001;

double posType       = OP_FLAT;
ulong  posTicket     = 0;
double posLots       = 0;
double posStopLoss   = 0;
double posTakeProfit = 0;

datetime barTime;
int      digits;
double   pip;
double   stopLevel;
bool     isTrailingStop=false;

ENUM_ORDER_TYPE_FILLING orderFillingType;

int ind0handler;
int ind1handler;
int ind2handler;
int ind3handler;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   barTime          = Time(0);
   digits           = (int) SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   pip              = GetPipValue(digits);
   stopLevel        = (int) SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   orderFillingType = GetOrderFillingType();
   isTrailingStop   = isTrailingStop && Stop_Loss > 0;

   ind0handler = iStochastic(NULL,0,Ind0Param0,Ind0Param1,Ind0Param2,MODE_SMA,0);
   ind1handler = iMACD(NULL,0,Ind1Param0,Ind1Param1,Ind1Param2,PRICE_CLOSE);
   ind2handler = iDeMarker(NULL,0,Ind2Param0);
   ind3handler = iADX(NULL,0,Ind3Param0);

   const ENUM_INIT_RETCODE initRetcode = ValidateInit();

   return (initRetcode);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime time=Time(0);
   if(time>barTime)
     {
      barTime=time;
      OnBar();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnBar()
  {
   UpdatePosition();

   if(posType!=OP_FLAT && IsForceSessionClose())
     {
      ClosePosition();
      return;
     }

   if(IsOutOfSession())
      return;

   if(posType!=OP_FLAT)
     {
      ManageClose();
      UpdatePosition();
     }

   if(posType!=OP_FLAT && isTrailingStop)
     {
      double trailingStop=GetTrailingStop();
      ManageTrailingStop(trailingStop);
      UpdatePosition();
     }

   if(posType==OP_FLAT)
     {
      ManageOpen();
      UpdatePosition();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePosition()
  {
   posType   = OP_FLAT;
   posTicket = 0;
   posLots   = 0;
   int posTotal=PositionsTotal();
   for(int posIndex=0;posIndex<posTotal;posIndex++)
     {
      const ulong ticket=PositionGetTicket(posIndex);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==Magic_Number)
        {
         posType       = (int) PositionGetInteger(POSITION_TYPE);
         posLots       = NormalizeDouble(PositionGetDouble(POSITION_VOLUME), 2);
         posTicket     = ticket;
         posStopLoss   = NormalizeDouble(PositionGetDouble(POSITION_SL), digits);
         posTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), digits);
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOpen()
  {
   double ind0buffer[]; CopyBuffer(ind0handler,MAIN_LINE,1,3,ind0buffer);
   double ind0val1 = ind0buffer[2];
   double ind0val2 = ind0buffer[1];
   bool ind0long  = ind0val1 < ind0val2 - sigma;
   bool ind0short = ind0val1 > ind0val2 + sigma;

   double ind1buffer0[]; CopyBuffer(ind1handler,0,1,3,ind1buffer0);
   double ind1buffer1[]; CopyBuffer(ind1handler,1,1,3,ind1buffer1);
   double ind1val1 = ind1buffer0[2] - ind1buffer1[2];
   double ind1val2 = ind1buffer0[1] - ind1buffer1[1];
   bool ind1long  = ind1val1 < 0 - sigma && ind1val2 > 0 + sigma;
   bool ind1short = ind1val1 > 0 + sigma && ind1val2 < 0 - sigma;

   double ind2buffer[]; CopyBuffer(ind2handler,0,1,3,ind2buffer);
   double ind2val1 = ind2buffer[2];
   double ind2val2 = ind2buffer[1];
   double ind2val3 = ind2buffer[0];
   bool ind2long  = ind2val1 > ind2val2 + sigma && ind2val2 < ind2val3 - sigma;
   bool ind2short = ind2val1 < ind2val2 - sigma && ind2val2 > ind2val3 + sigma;

   const bool canOpenLong  = ind0long && ind1long && ind2long;
   const bool canOpenShort = ind0short && ind1short && ind2short;

   if(canOpenLong && canOpenShort) return;

   if(canOpenLong)
      OpenPosition(OP_BUY);
   else if(canOpenShort)
      OpenPosition(OP_SELL);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageClose()
  {
   double ind3buffer0[]; CopyBuffer(ind3handler,1,1,3,ind3buffer0);
   double ind3buffer1[]; CopyBuffer(ind3handler,2,1,3,ind3buffer1);
   double ind3val1 = ind3buffer0[2] - ind3buffer1[2];
   bool ind3long  = ind3val1 > 0 + sigma;
   bool ind3short = ind3val1 < 0 - sigma;

   if(posType==OP_BUY && ind3long)
      ClosePosition();
   else if(posType==OP_SELL && ind3short)
      ClosePosition();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPosition(int command)
  {
   const double stopLoss   = GetStopLossPrice(command);
   const double takeProfit = GetTakeProfitPrice(command);
   ManageOrderSend(command,Entry_Amount,stopLoss,takeProfit,0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePosition()
  {
   const int command=posType==OP_BUY ? OP_SELL : OP_BUY;
   ManageOrderSend(command,posLots,0,0,posTicket);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOrderSend(int command,double lots,double stopLoss,double takeProfit,ulong ticket)
  {
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         ResetLastError();
         MqlTick         tick;    SymbolInfoTick(_Symbol,tick);
         MqlTradeRequest request; ZeroMemory(request);
         MqlTradeResult  result;  ZeroMemory(result);

         request.action       = TRADE_ACTION_DEAL;
         request.symbol       = _Symbol;
         request.volume       = lots;
         request.type         = command==OP_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         request.price        = command==OP_BUY ? tick.ask : tick.bid;
         request.type_filling = orderFillingType;
         request.deviation    = 10;
         request.sl           = stopLoss;
         request.tp           = takeProfit;
         request.magic        = Magic_Number;
         request.position     = ticket;
         request.comment      = IntegerToString(Magic_Number);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            isOrderSend=OrderSend(request,result);
           }

         if(isOrderCheck && isOrderSend && result.retcode==TRADE_RETCODE_DONE)
            return;
        }
      Sleep(TRADE_RETRY_WAIT);
      Print("Order Send retry no: "+IntegerToString(attempt+2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(double stopLoss,double takeProfit,ulong ticket)
  {
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         ResetLastError();
         MqlTick         tick;    SymbolInfoTick(_Symbol,tick);
         MqlTradeRequest request; ZeroMemory(request);
         MqlTradeResult  result;  ZeroMemory(result);

         request.action   = TRADE_ACTION_SLTP;
         request.symbol   = _Symbol;
         request.sl       = stopLoss;
         request.tp       = takeProfit;
         request.magic    = Magic_Number;
         request.position = ticket;
         request.comment  = IntegerToString(Magic_Number);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            isOrderSend=OrderSend(request,result);
           }

         if(isOrderCheck && isOrderSend && result.retcode==TRADE_RETCODE_DONE)
            return;
        }
      Sleep(TRADE_RETRY_WAIT);
      Print("Order Send retry no: "+IntegerToString(attempt+2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckOrder(MqlTradeRequest &request)
  {
   MqlTradeCheckResult check; ZeroMemory(check);
   const bool isOrderCheck=OrderCheck(request,check);
   if(isOrderCheck) return (true);


   if(check.retcode==TRADE_RETCODE_INVALID_FILL)
     {
      switch(orderFillingType)
        {
         case  ORDER_FILLING_FOK:
            orderFillingType=ORDER_FILLING_IOC;
            break;
         case  ORDER_FILLING_IOC:
            orderFillingType=ORDER_FILLING_RETURN;
            break;
         case  ORDER_FILLING_RETURN:
            orderFillingType=ORDER_FILLING_FOK;
            break;
        }

      request.type_filling=orderFillingType;

      const bool isNewCheck=CheckOrder(request);

      return (isNewCheck);
     }

   Print("Error with OrderCheck: "+check.comment);
   return (false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStopLossPrice(int command)
  {
   if(Stop_Loss==0) return (0);

   MqlTick tick; SymbolInfoTick(_Symbol,tick);
   const double delta    = MathMax(pip*Stop_Loss, _Point*stopLevel);
   const double price    = command==OP_BUY ? tick.bid : tick.ask;
   const double stopLoss = command==OP_BUY ? price-delta : price+delta;
   const double normalizedStopLoss = NormalizeDouble(stopLoss, _Digits);

   return (normalizedStopLoss);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTrailingStop()
  {
   MqlTick tick; SymbolInfoTick(_Symbol,tick);
   const double stopLevelPoints = _Point*stopLevel;
   const double stopLossPoints  = pip*Stop_Loss;

   if(posType==OP_BUY)
     {
      const double stopLossPrice=High(1)-stopLossPoints;
      if(posStopLoss<stopLossPrice-pip)
        {
         if(stopLossPrice<tick.bid)
           {
            const double fixedStopLossPrice = (stopLossPrice>=tick.bid-stopLevelPoints)
                                              ? tick.bid - stopLevelPoints
                                              : stopLossPrice;

            return (fixedStopLossPrice);
           }
         else
           {
            return (tick.bid);
           }
        }
     }

   else if(posType==OP_SELL)
     {
      const double stopLossPrice=Low(1)+stopLossPoints;
      if(posStopLoss>stopLossPrice+pip)
        {
         if(stopLossPrice>tick.ask)
           {
            if(stopLossPrice<=tick.ask+stopLevelPoints)
               return (tick.ask + stopLevelPoints);
            else
               return (stopLossPrice);
           }
         else
           {
            return (tick.ask);
           }
        }
     }

   return (posStopLoss);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageTrailingStop(double trailingStop)
  {
   MqlTick tick; SymbolInfoTick(_Symbol,tick);

   if(posType==OP_BUY && MathAbs(trailingStop-tick.bid)<_Point)
     {
      ClosePosition();
     }

   else if(posType==OP_SELL && MathAbs(trailingStop-tick.ask)<_Point)
     {
      ClosePosition();
     }

   else if(MathAbs(trailingStop-posStopLoss)>_Point)
     {
      posStopLoss=NormalizeDouble(trailingStop,digits);
      ModifyPosition(posStopLoss,posTakeProfit,posTicket);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfitPrice(int command)
  {
   if(Take_Profit==0) return (0);

   MqlTick tick; SymbolInfoTick(_Symbol,tick);
   const double delta      = MathMax(pip*Take_Profit, _Point*stopLevel);
   const double price      = command==OP_BUY ? tick.bid : tick.ask;
   const double takeProfit = command==OP_BUY ? price+delta : price-delta;
   const double normalizedTakeProfit = NormalizeDouble(takeProfit, _Digits);

   return (normalizedTakeProfit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time(int bar)
  {
   datetime buffer[]; ArrayResize(buffer,1);
   const int result=CopyTime(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Open(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyOpen(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double High(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyHigh(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Low(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyLow(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Close(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyClose(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetPipValue(int digit)
  {
   if(digit==4 || digit==5)
      return (0.0001);
   if(digit==2 || digit==3)
      return (0.01);
   if(digit==1)
      return (0.1);
   return (1);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeContextFree()
  {
   if(MQL5InfoInteger(MQL5_TRADE_ALLOWED)) return (true);

   uint startWait=GetTickCount();
   Print("Trade context is busy! Waiting...");

   while(true)
     {
      if(IsStopped()) return (false);

      uint diff=GetTickCount()-startWait;
      if(diff>30*1000)
        {
         Print("The waiting limit exceeded!");
         return (false);
        }

      if(MQL5InfoInteger(MQL5_TRADE_ALLOWED)) return (true);

      Sleep(TRADE_RETRY_WAIT);
     }

   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOutOfSession()
  {
   MqlDateTime time0; TimeToStruct(Time(0),time0);
   const int weekDay           = time0.day_of_week;
   const long timeFromMidnight = Time(0)%86400;
   const int periodLength      = PeriodSeconds(_Period);

   if(weekDay==0)
     {
      if(sessionIgnoreSunday) return (true);

      const int lastBarFix = sessionCloseAtSessionClose ? periodLength : 0;
      const bool skipTrade = timeFromMidnight<sessionSundayOpen ||
                             timeFromMidnight+lastBarFix>sessionSundayClose;

      return (skipTrade);
     }

   if(weekDay<5)
     {
      const int lastBarFix = sessionCloseAtSessionClose ? periodLength : 0;
      const bool skipTrade = timeFromMidnight<sessionMondayThursdayOpen ||
                             timeFromMidnight+lastBarFix>sessionMondayThursdayClose;

      return (skipTrade);
     }

   const int lastBarFix=sessionCloseAtFridayClose || sessionCloseAtSessionClose ? periodLength : 0;
   const bool skipTrade=timeFromMidnight<sessionFridayOpen || timeFromMidnight+lastBarFix>sessionFridayClose;

   return (skipTrade);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsForceSessionClose()
  {
   if(!sessionCloseAtFridayClose && !sessionCloseAtSessionClose) return (false);

   MqlDateTime time0; TimeToStruct(Time(0),time0);
   const int weekDay           = time0.day_of_week;
   const long timeFromMidnight = Time(0)%86400;
   const int periodLength      = PeriodSeconds(_Period);

   bool forceExit=false;
   if(weekDay==0 && sessionCloseAtSessionClose)
     {
      forceExit=timeFromMidnight+periodLength>sessionSundayClose;
     }
   else if(weekDay<5 && sessionCloseAtSessionClose)
     {
      forceExit=timeFromMidnight+periodLength>sessionMondayThursdayClose;
     }
   else if(weekDay==5)
     {
      forceExit=timeFromMidnight+periodLength>sessionFridayClose;
     }

   return (forceExit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetOrderFillingType()
  {
   const int oftIndex=(int) SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   const ENUM_ORDER_TYPE_FILLING fillType=(ENUM_ORDER_TYPE_FILLING)(oftIndex>0 ? oftIndex-1 : oftIndex);

   return (fillType);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INIT_RETCODE ValidateInit()
  {
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
/*STRATEGY MARKET Premium Data; USDCAD; H1 */
/*STRATEGY CODE {"properties":{"entryLots":0.01,"stopLoss":54,"takeProfit":201,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Stochastic","listIndexes":[1,0,0,0,0],"numValues":[19,2,2,20,0,0]},{"name":"MACD Signal","listIndexes":[1,3,0,0,0],"numValues":[9,18,3,0,0,0]},{"name":"DeMarker","listIndexes":[6,0,0,0,0],"numValues":[48,0,0,0,0,0]}],"closeFilters":[{"name":"Directional Indicators","listIndexes":[2,0,0,0,0],"numValues":[36,0,0,0,0,0]}]} */
