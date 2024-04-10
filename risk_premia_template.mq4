

/*
   This file contains a script for a generic Risk Premia trading strategy. 
   
   Sends a BUY signal when Skewness is lower than minimum threshold, 
   and a SELL signal when Skewness is higher than maximum threshold. 
   
   This script is based on the article from QuantConnect 
   "Risk Premia in Forex Markets"
   
   Link: https://www.quantconnect.com/research/15305/risk-premia-in-forex-markets/p1
   
   DISCLAIMER: This script does not guarantee future profits, and is 
   created for demonstration purposes only. Do not use this script 
   with live funds. 
*/


#include <B63/Generic.mqh> 
#include "trade_ops.mqh"

enum ENUM_SIGNAL {
   SIGNAL_LONG,
   SIGNAL_SHORT,
   SIGNAL_NONE
}; 


input int      InpMagic                   = 111111;
input int      InpSkewPeriod              = 10; 
input double   InpSkewThrehsold           = 0.6; 


class CSkewTrade : public CTradeOps {
private:
   int      skew_period_; 
   double   skew_upper_threshold_, skew_lower_threshold_; 

public:
   CSkewTrade();
   ~CSkewTrade(); 
            int               SkewPeriod()   const { return skew_period_; }
            double            SkewUpper()    const { return skew_upper_threshold_; }
            double            SkewLower()    const { return skew_lower_threshold_; }

            void              Stage();
            ENUM_SIGNAL       Signal();
            double            SkewValue(); 
            int               SendOrder(ENUM_SIGNAL signal); 
            int               ClosePositions(ENUM_ORDER_TYPE order_type);
            bool              DeadlineReached(); 
}; 

CSkewTrade::CSkewTrade() 
   : CTradeOps(Symbol(), InpMagic)
   , skew_period_(InpSkewPeriod)
   , skew_upper_threshold_(MathAbs(InpSkewThrehsold))
   , skew_lower_threshold_(-MathAbs(InpSkewThrehsold)) {}
   
CSkewTrade::~CSkewTrade() {}

bool        CSkewTrade::DeadlineReached() {
   return TimeHour(TimeCurrent()) >= 20; 
}

double      CSkewTrade::SkewValue() {
   //--- path = \\b63\\statistics\\
   //--- name = skew 
   //--- indicator_path = \\b63\\statistics\\skew
   return iCustom(
      NULL,
      PERIOD_CURRENT,
      "\\b63\\statistics\\skew",
      SkewPeriod(),
      0, // shift 
      0, // buffer
      1  // shift
   );
}

void        CSkewTrade::Stage() {
   if (DeadlineReached()) {
      ClosePositions(ORDER_TYPE_BUY);
      ClosePositions(ORDER_TYPE_SELL);
      return; 
   }
   
   ENUM_SIGNAL signal = Signal();
   if (signal == SIGNAL_NONE) return; 
   SendOrder(signal); 
}

ENUM_SIGNAL CSkewTrade::Signal() {
   double skew_value = SkewValue(); 
   
   if (skew_value > SkewUpper()) return SIGNAL_SHORT; 
   if (skew_value < SkewLower()) return SIGNAL_LONG;
   return SIGNAL_NONE; 
}

int         CSkewTrade::SendOrder(ENUM_SIGNAL signal) {
   ENUM_ORDER_TYPE order_type;
   double entry_price;
   
   switch(signal) {
      case SIGNAL_LONG:
         order_type  = ORDER_TYPE_BUY;
         entry_price = UTIL_PRICE_ASK(); 
         ClosePositions(ORDER_TYPE_SELL); 
         break; 
      case SIGNAL_SHORT:
         order_type  = ORDER_TYPE_SELL; 
         entry_price = UTIL_PRICE_BID();
         ClosePositions(ORDER_TYPE_BUY);
         break;
      case SIGNAL_NONE:
         return -1; 
      default:
         return -1; 
   }
   return OP_OrderOpen(Symbol(), order_type, 0.01, entry_price, 0, 0, NULL); 
}

int         CSkewTrade::ClosePositions(ENUM_ORDER_TYPE order_type) {
   if (PosTotal() == 0) return 0; 
   
   CPoolGeneric<int> *tickets = new CPoolGeneric<int>(); 
   
   for (int i = 0; i < PosTotal(); i++) {
      int s = OP_OrderSelectByIndex(i); 
      int ticket = PosTicket();
      if (!OP_TradeMatchTicket(ticket)) continue; 
      if (PosOrderType() != order_type) continue;
      tickets.Append(ticket);
   }
   int extracted[]; 
   int num_extracted = tickets.Extract(extracted);
   OP_OrdersCloseBatch(extracted); 
   delete tickets;
   return num_extracted; 
}

CSkewTrade     skew_trade; 

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
//---
   if (IsNewCandle()) {
      skew_trade.Stage(); 
   }
   
  }
//+------------------------------------------------------------------+
