//+------------------------------------------------------------------+
//|                                                        My_EA.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"


input int per = 40;
input ENUM_MA_METHOD  iMethod =MODE_SMA;
input ENUM_APPLIED_PRICE iPrice=PRICE_CLOSE;
double avg,close;
input int MagicNumber=1;
input double lote    =0.10;
input int     SL     =200;
input int     TP     =300;

int slippage=150;
datetime time;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
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
   avg = iMA(NULL,PERIOD_CURRENT,per,0,iMethod,iPrice,1);
   close =iClose(NULL,0,1);

///Compras///

   if(close > avg && time!=iTime(NULL,0,0))
     {
      OrderSend(NULL,OP_BUY,lote,Ask,slippage,0,Ask + (TP*Point()),"OP_BUY-AVG",MagicNumber,0,clrGreen);
      time=iTime(NULL,0,0);
     }

   for(int cnt=0; cnt<OrdersTotal(); cnt++)
     {
      if(OrderMagicNumber()==MagicNumber)
        {
         if(OrderType() == OP_BUY)
           {
            if(close < avg)
              {
               OrderClose(OrderTicket(),OrderLots(),Bid,slippage,clrRed);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
