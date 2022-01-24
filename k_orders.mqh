//+------------------------------------------------------------------+
//|                                                     K_Orders.mqh |
//|                                                   Karlis Balcers |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Karlis Balcers"
#property link      "http://www.mql5.com"

#include <Trade\PositionInfo.mqh>
CPositionInfo positionInfo;
//+------------------------------------------------------------------+
//| Order                                                            |
//+------------------------------------------------------------------+
class Order{
   private:
      MqlTradeRequest   trReq;
      MqlTradeResult    trRez;
      int               iSL;
      int               iTP;
      double            dSL;
      double            dTP;
      
      enum operationType{
         buy_operation, 
         sell_operation
      }; 
      
      ulong orderTry; //aggiunto da me
      ulong positionBuyTicket, positionSellTicket;

      double GetSL(bool forBUY){
      
         if(iSL>0){
            if(forBUY){
               return SymbolInfoDouble(trReq.symbol,SYMBOL_ASK)-iSL*_Point;
            }else{
               return SymbolInfoDouble(trReq.symbol,SYMBOL_BID)+iSL*_Point;
            }
         }else
            return dSL;
      }

      double GetTP(bool forBUY){
         if(iTP>0){
            if(forBUY){
               return SymbolInfoDouble(trReq.symbol,SYMBOL_ASK)+iTP*_Point;
            }else{
               return SymbolInfoDouble(trReq.symbol,SYMBOL_BID)-iTP*_Point;
            }
         }else 
            return dTP;
      }

      void VerifySLTP(bool buy){
         double minSapce=SymbolInfoInteger(trReq.symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;

         if(buy){
            if(trReq.sl!=0)
               if(SymbolInfoDouble(trReq.symbol,SYMBOL_BID)-trReq.sl<minSapce)
                  trReq.sl=SymbolInfoDouble(trReq.symbol,SYMBOL_BID)-minSapce;
   
            if(trReq.tp!=0)
               if(trReq.tp - trReq.price < minSapce)
                  trReq.tp=trReq.price+minSapce;
         }else{
            if(trReq.sl!=0)
               if(trReq.sl - SymbolInfoDouble(trReq.symbol,SYMBOL_ASK) < minSapce)
                  trReq.sl=SymbolInfoDouble(trReq.symbol,SYMBOL_ASK)+minSapce;
   
            if(trReq.tp!=0)
               if(trReq.price - trReq.tp  < minSapce)
                  trReq.tp=trReq.price-minSapce;
         }
      }

      public: 
         
         Order(){
            ZeroMemory(trReq);
            trReq.action=TRADE_ACTION_DEAL;
            trReq.magic=0;
            trReq.symbol=Symbol();
            trReq.volume=0.1;
            trReq.price=0;
            trReq.sl=0;               // Stop Loss level of the order
            trReq.tp=0;               // Take Profit level of the order
            trReq.deviation=5;        // Maximal possible deviation from the requested price
            trReq.type=0;
            trReq.type_filling=ORDER_FILLING_IOC;
            trReq.type_time=ORDER_TIME_GTC;
            trReq.expiration=0;
            trReq.comment="";
         
            iSL=0;
            iTP=0;
            dSL=0;
            dTP=0;
         }

         bool Buy(){
            trReq.type=ORDER_TYPE_BUY;
            trReq.price=SymbolInfoDouble(trReq.symbol,SYMBOL_ASK);
            trReq.sl=GetSL(true);
            trReq.tp=GetTP(true);
      
            VerifySLTP(true);
            
            printf("try to buy");
            
            orderTry=0;
      
            return Execute();
         }
   
         bool Sell(){
            trReq.type=ORDER_TYPE_SELL;
            trReq.price=SymbolInfoDouble(trReq.symbol,SYMBOL_BID);
            trReq.sl=GetSL(false);
            trReq.tp=GetTP(false);
      
            VerifySLTP(false);
            
            printf("try to sell");
            
            orderTry=0;
      
            return Execute();
         }

         bool Close(ENUM_ORDER_TYPE operation){
            if(PositionSelect(trReq.symbol)){
            
               if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
                  trReq.type = ORDER_TYPE_SELL;
                  trReq.type = ORDER_TYPE_CLOSE_BY; //aggiunto da me
                  trReq.price=SymbolInfoDouble(trReq.symbol,SYMBOL_BID);
               }else{
                  trReq.type = ORDER_TYPE_BUY;
                  trReq.type = ORDER_TYPE_CLOSE_BY; //aggiunto da me
                  trReq.price=SymbolInfoDouble(trReq.symbol,SYMBOL_ASK);
               }
               
               printf("try to close...");
               
               double vol=trReq.volume;
               trReq.sl=0;
               trReq.tp=0;
               trReq.volume=PositionGetDouble(POSITION_VOLUME);
               bool ret=Execute();
               if(ret)
                  printf("Order Closed");
               trReq.volume=vol;
         
               return ret;
            }else{
               Print("Position can not be selected.");
            }
            return true;
         }

         bool Modify(ENUM_ORDER_TYPE operation){
         
            ulong ticket;                        
            
            if( operation == ORDER_TYPE_BUY ){
               setTicket(ORDER_TYPE_BUY);
               ticket = positionBuyTicket;               
            }else{
               setTicket(ORDER_TYPE_SELL);
               ticket = positionSellTicket;
            }
            
            printf("ticket=" + ticket);
               
            if(PositionSelectByTicket(ticket)){
               trReq.action=TRADE_ACTION_SLTP;
               printf("try to modify...");
               
               if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
                  trReq.sl=GetSL(true);
                  trReq.tp=GetTP(true);
                  VerifySLTP(true);
               }else{
                  trReq.sl=GetSL(false);
                  trReq.tp=GetTP(false);
                  VerifySLTP(false);
               }
               if(PositionGetDouble(POSITION_SL)==trReq.sl && PositionGetDouble(POSITION_TP)==trReq.tp)
                  return true;
               bool retval=Execute();
               trReq.action=TRADE_ACTION_DEAL;
               return retval;
            }else{
               Print("Modify()| Position can not be selected." + " Symbol:" + trReq.symbol);
            }
            return false;
         }
         /*
         bool Close_Volume(double volume){
            if(PositionSelect(trReq.symbol))
              {
               if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
                 {
                  trReq.type = ORDER_TYPE_SELL;
                  trReq.price=SymbolInfoDouble(trReq.symbol,SYMBOL_BID);
                 }
               else
                 {
                  trReq.type = ORDER_TYPE_BUY;
                  trReq.price=SymbolInfoDouble(trReq.symbol,SYMBOL_ASK);
                 }
               double vol=trReq.volume;
               trReq.sl=0;
               trReq.tp=0;
               trReq.volume=volume;
               bool ret=Execute();
               trReq.volume=vol;
      
               return ret;
              }
            else
              {
               Print("Position can not be selected.");
              }
            return true;
         }
         */
         bool Execute(){
            bool err=OrderSend(trReq, trRez);
            if(!err){
               Print("Execution of new order failed! Error = ",GetLastError());
               printf("Error:", GetLastError());
               if(orderTry < 5){
                  orderTry++;
                  Execute();
               }
               return false;
            }else{
               printf("Order executed");                              
                 
               return true;
            }
            
         }
         
         void setTicket( ENUM_ORDER_TYPE orderType ){
         
            for(int i=0; i<=PositionsTotal();i++){
               if(positionInfo.SelectByIndex(i)){     // selects the position by index for further access to its properties
                  if(positionInfo.Symbol()==Symbol()){
                     if( orderType == ORDER_TYPE_BUY ){
                        positionBuyTicket = PositionGetTicket(i);
                     }else if( orderType == ORDER_TYPE_SELL ){
                        positionSellTicket = PositionGetTicket(i);
                     }     
                  }
               }       
            }
         
         }

   //==============

   void SetMagic(int magic)
     {
      trReq.magic=magic;
     }

   void SetComment(string comment)
     {
      trReq.comment=comment;
     }

   void SetLots(double lots){
      trReq.volume=lots;
   }

   void SetSL_inPrice(double sl_price)
     {
      iSL=0;
      dSL=sl_price;
     }

   void SetTP_inPrice(double tp_price)
     {
      iTP=0;
      dTP=tp_price;
     }

   void SetSL_inPoints(int sl)
     {
      dSL=0;
      iSL=sl;
     }

   void SetTP_inPoints(int tp)
     {
      dTP=0;
      iTP=tp;
     }

};
//+------------------------------------------------------------------+
