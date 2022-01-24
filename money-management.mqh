//+------------------------------------------------------------------+
//|                                             money-management.mq5 |
//|                                                           andrea |
//+------------------------------------------------------------------+
#property copyright "andrea"

class MoneyManagement{

   private:
   
      double lots;
      
   
   public:
      
      double getLots(){
         return lots;
      }
      
      void setLotsByStopLossAndRiskPercentage(double riskPercentage, int stopLossInPoints){
      
         double pipValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
         double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         double maxRiskInPrice = accountBalance * (riskPercentage / 100);
         
         lots = maxRiskInPrice  / (pipValue * stopLossInPoints) ; 
         lots = floor(lots * 100) / 100; 
         lots = NormalizeDouble(lots, 2);
         
         if( lots > SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX) ){
            lots = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
         }else if( lots < SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN) ){
            printf("Error: minimum lots not excedeed");
         }
         
         printf("lotsCalculatedForRiskPercentage=" + lots);
         
         //printf("accountBalance=" + accountBalance + " maxRiskInPrice=" + maxRiskInPrice + " riskPercentage=" + riskPercentage  + " pipValue=" + pipValue + " stopLossInPoints=" + stopLossInPoints + "  lots=" + lots );
         
      }
      
      void setMaxLotsByFreeMargin(ulong magic, double price, double stopLoss, double takeProfit, ENUM_ORDER_TYPE order){
         
         MqlTradeRequest mtr;
         MqlTradeCheckResult mtcr;
         
         mtr.action = TRADE_ACTION_DEAL;
         mtr.magic = magic;
         mtr.order = 0;
         mtr.symbol = Symbol();
         mtr.volume = getLots();
         mtr.price = price;
         mtr.stoplimit = 0;
         mtr.sl = stopLoss;
         mtr.tp = takeProfit;
         mtr.deviation = 5;
         mtr.type = order;
         mtr.type_filling = ORDER_FILLING_IOC;
         mtr.type_time = ORDER_TIME_GTC;
         mtr.expiration = 0;
         mtr.comment = "";
        
         bool check = OrderCheck(mtr, mtcr);
        
         if(!check){
            lots = lots - 0.01;      
            setMaxLotsByFreeMargin(magic, price, stopLoss, takeProfit, order);
         }
         
      }
   
};