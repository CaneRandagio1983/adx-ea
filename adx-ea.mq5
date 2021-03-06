//+---------------------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                      adx-ea.mq5 |
//|                                                                                                                    canerandagio |
//|                                                                                                                                 |
//+---------------------------------------------------------------------------------------------------------------------------------+

//+---------------------------------------------------------------------------------------------------------------------------------+
//|                                                                                                                                 |
//|   bugs:                                                                                                                         |
//|                                                                                                                                 |
//|   operatività:                                                                                                                  |
//|      1. il be viene impostato troppo presto                                                                                     |
//|      2. non bisogna tornare a mercato fino a che non si rincrociano dip e dim                                                   |
//|                                                                                                                                 |
//|   considerazioni:                                                                                                               |
//|                                                                                                                                 |
//|   todo:                                                                                                                         |
//|      1. alzare i pips per il be                                                                                                 |
//|      2. modificare il setup di entrata, aspettare che si rincrocino dip e dim                                                   |
//+---------------------------------------------------------------------------------------------------------------------------------+
#property copyright "andrea"
#property version   "1.00"

#include "K_Orders.mqh"
#include "money-management.mqh"
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Strings\String.mqh>

Order order; 
MoneyManagement moneyManagement;
CTrade cTrade; 
CSymbolInfo cSymbolInfo;
CHistoryOrderInfo cHistoryOrderInfo;
CString cString;

#resource "\\Indicators\\Examples\\ADX.ex5"
#resource "\\Indicators\\Examples\\ZigZag.ex5"

int adxHandle = INVALID_HANDLE;
int adxDIPHandle = INVALID_HANDLE;
int adxDIMHandle = INVALID_HANDLE;

double adxBuffer[];
double adxDIPBuffer[];
double adxDIMBuffer[];

int zigZagHandle=INVALID_HANDLE;

double zigZagBuffer[];
double zigZagHighBuffer[];
double zigZagLowBuffer[];

input int riskPercentage = 5;
input int stopLossSurplus = 4;
input double trailingStopFactor = 0.7;
input int minPipsToChangeTrailingStop = 60;
input int minPipsToGoBreakHeaven = 25;

input int adxPeriod = 14;
input int adxTrendLevel = 20;

bool isInTheMarket = false;
bool isInBuy = false;
bool isInSell = false;

bool isADXReady = true;
enum ADXStatus{ bull, bear, neutral} adxStatus;
bool isADXForBuy = true;
bool isADXForSell = true;

bool isBreakHeaven = false;

double orderPriceOpen;

int OnInit(){

   if( ( adxHandle=iCustom(_Symbol, _Period, "::Indicators\\Examples\\ADX.ex5", adxPeriod) ) == INVALID_HANDLE )
      return(INIT_FAILED);
      
   if( ( adxDIPHandle=iCustom(_Symbol, _Period, "::Indicators\\Examples\\ADX.ex5", adxPeriod) ) == INVALID_HANDLE )
      return(INIT_FAILED);
      
   if( ( adxDIMHandle=iCustom(_Symbol, _Period, "::Indicators\\Examples\\ADX.ex5", adxPeriod) ) == INVALID_HANDLE )
      return(INIT_FAILED);
   
   if( (zigZagHandle=iCustom(_Symbol, _Period, "::Indicators\\Examples\\ZigZag.ex5", 3, 5, 1)) == INVALID_HANDLE )
      return(INIT_FAILED);
      
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   
   IndicatorRelease(adxHandle);
   IndicatorRelease(adxDIPHandle);
   IndicatorRelease(adxDIMHandle);
   IndicatorRelease(zigZagHandle);   
   
}

void OnTick(){
   
   createBuffers();
   
   //open position
   if(!isInTheMarket){
      if(isADXSetupForBuy() && isADXForBuy && isADXReady){
         buy();
      }else if(isADXSetupForSell() && isADXForSell && isADXReady){
         sell();
      }
   }
   
   //change trailing stop
   if(isInTheMarket && isTimeToChangeTrailingStop())
      changeTrailingStop();
   
   //break heaven
   if(isInTheMarket && isTimeToGoToBreakHeaven())
      goToBreakHeaven();
   
   // fix the variables
   if( isPositionOpen() ){
   
      isInTheMarket = true;
      
      if( positionInfo.PositionType() == POSITION_TYPE_BUY )
         isInBuy = true;
      else if( positionInfo.PositionType() == POSITION_TYPE_SELL )
         isInSell = true;
   }else{
      isInTheMarket = false;
      isInBuy = false;
      isInSell = false;
      isBreakHeaven = false;
   }   
   
   if(adxDIPBuffer[0] > adxDIMBuffer[0]){
      isADXForBuy = true;
      isADXForSell = false;
   }else if(adxDIPBuffer[0] < adxDIMBuffer[0]){
      isADXForBuy = false;
      isADXForSell = true;
   }else{
      isADXForBuy = false;
      isADXForSell = false;
   }
   
   
   setADXStatusAndIsADXReady();   
   
}

void createBuffers(){

   if(CopyBuffer( adxHandle, 0, 0, 2, adxBuffer ) <= 0)
      printf("Error:" + GetLastError() + " error in CopyBuffer adxBuffer");
   else
      ArraySetAsSeries(adxBuffer, true);
      
      
   if(CopyBuffer( adxDIPHandle, 1, 0, 2, adxDIPBuffer ) <= 0)
      printf("Error:" + GetLastError() + " error in CopyBuffer adxDIPBuffer");
   else
      ArraySetAsSeries(adxDIPBuffer, true);
      
   
   if(CopyBuffer( adxDIMHandle, 2, 0, 2, adxDIMBuffer ) <= 0)
      printf("Error:" + GetLastError() + " error in CopyBuffer adxDIMBuffer");
   else
      ArraySetAsSeries(adxDIMBuffer, true);
      
      
   if(CopyBuffer(zigZagHandle, 0, 0, 100, zigZagBuffer) <= 0)
      printf("Error:" + GetLastError() + " error in CopyBuffer ExtSlowSMABuffer");
   else
      ArraySetAsSeries(zigZagBuffer, true);      
      
      
   if(CopyBuffer(zigZagHandle, 1, 0, 100, zigZagHighBuffer) <= 0)
      printf("Error:" + GetLastError() + " error in CopyBuffer ExtSlowSMABuffer");
   else
      ArraySetAsSeries(zigZagHighBuffer, true);
      
      
   if(CopyBuffer(zigZagHandle, 2, 0, 100, zigZagLowBuffer) <= 0)
      printf("Error:" + GetLastError() + " error in CopyBuffer ExtSlowSMABuffer");
   else
      ArraySetAsSeries(zigZagLowBuffer, true);
   

}

void setADXStatusAndIsADXReady(){

   //set adxStatus and isADXReady when dip and dim cross themself
   if( ( (adxStatus == bull) || (adxStatus == neutral) ) && (isADXForSell == true) && (isADXReady == false) ){
      adxStatus = bear;
      isADXReady = true;
   }else if( ( (adxStatus == bear) || (adxStatus == neutral) ) && (isADXForBuy == true) && (isADXReady == false)){
      adxStatus = bull;
      isADXReady = true;
   }

}

bool isADXSetupForBuy(){

   if( (adxBuffer[0] > adxTrendLevel) && (adxDIPBuffer[0] > adxDIMBuffer[0] ) )
      return true;
   else
      return false;
      
}

bool isADXSetupForSell(){

   if( (adxBuffer[0] > adxTrendLevel) && ( adxDIPBuffer[0] < adxDIMBuffer[0] ) )
      return true;
   else
      return false;
      
}

void buy(){

   printf("buy");

   bool operation;
   double price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double sl = getStopLossInPrice(ORDER_TYPE_BUY);
   int slInPt = getStopLossInPoints(ORDER_TYPE_BUY);
   double tp;
   
   moneyManagement.setLotsByStopLossAndRiskPercentage(riskPercentage, slInPt);
   moneyManagement.setMaxLotsByFreeMargin(0, price, sl, tp, ORDER_TYPE_BUY);
   operation = cTrade.Buy(moneyManagement.getLots(), Symbol(), NULL, sl, tp ); 
   
   if( operation ){
      isADXReady = false;
      isInTheMarket = true;
      isInBuy = true;      
      orderPriceOpen = price;
   }else{
      printf("error:" + GetLastError());
   }
   
}

void sell(){

   printf("sell");

   bool operation;
   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double sl = getStopLossInPrice(ORDER_TYPE_SELL);
   int slInPt = getStopLossInPoints(ORDER_TYPE_SELL);
   double tp;
   
   moneyManagement.setLotsByStopLossAndRiskPercentage(riskPercentage, slInPt);
   moneyManagement.setMaxLotsByFreeMargin(0, price, sl, tp, ORDER_TYPE_SELL);
   operation = cTrade.Sell(moneyManagement.getLots(), Symbol(), NULL, sl, tp ); 
   
   if( operation ){
      isADXReady = false;
      isInTheMarket = true;
      isInSell = true;   
      orderPriceOpen = price;   
   }else{
      printf("error:" + GetLastError());
   }
   
}

//return stoploss in price
double getStopLossInPrice(ENUM_ORDER_TYPE orderType){

   double stopLossInPrice;
   
   if(orderType == ORDER_TYPE_BUY){

      for(int i=0;i<99;i++){
         if(zigZagLowBuffer[i] > 0){
            stopLossInPrice = iLow(Symbol(), Period(), i) - (Point() * stopLossSurplus);
            break;
         }
         
      }     
   
   }else if(orderType == ORDER_TYPE_SELL){
   
      for(int i=0;i<99;i++){
         if(zigZagHighBuffer[i] > 0){
            stopLossInPrice = iHigh(Symbol(), Period(), i) + (Point() * stopLossSurplus);
            break;
         }

      }      
   
   }
      
   return stopLossInPrice;
}

//return stoploss in points
int getStopLossInPoints(ENUM_ORDER_TYPE orderType){

   int stopLossInPoints;
   double stopLossInPrice;
   

   if(orderType == ORDER_TYPE_BUY){
   
      for(int i=0;i<99;i++){
         if(zigZagLowBuffer[i] > 0){
            stopLossInPrice = iLow(Symbol(), Period(), i) - (Point() * 4);
            break;
         }
         
      }
      
      stopLossInPoints = (SymbolInfoDouble(Symbol(),SYMBOL_ASK ) - stopLossInPrice) / Point();
      
   }else if(orderType == ORDER_TYPE_SELL){
   
      for(int i=0;i<99;i++){
         if(zigZagHighBuffer[i] > 0){
            stopLossInPrice = iHigh(Symbol(), Period(), i) + (Point() * 4);
            break;
         }
   
     }
     stopLossInPoints = (stopLossInPrice - SymbolInfoDouble(Symbol(),SYMBOL_BID)) / Point();
  
   }
   
   return stopLossInPoints;
}
/*
double getTakeProfitInPrice(ENUM_ORDER_TYPE orderType){

   double price;
      
   switch(orderType){   
   
      case ORDER_TYPE_BUY:
         price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         return price + (trailingStopInPoints * Point());
         break;
         
      case ORDER_TYPE_SELL:
         price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         return price - (trailingStopInPoints * Point());
         break;
   
   }
   
   return 0;

}
*/
bool isTimeToChangeTrailingStop(){

   double price;
   int pipsInGain;

   if(positionInfo.PositionType() == POSITION_TYPE_BUY){
         price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
         pipsInGain = ( price - orderPriceOpen ) / Point();
   }else if(positionInfo.PositionType() == POSITION_TYPE_SELL){
         price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
         pipsInGain = ( orderPriceOpen - price ) / Point();
   }

   if( pipsInGain >= minPipsToChangeTrailingStop ){
      return true;
   }else{
      return false;
   }

}

bool isTimeToGoToBreakHeaven(){
   
   double price;
   int pipsInGain;

   if(positionInfo.PositionType() == POSITION_TYPE_BUY){
         price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
         pipsInGain = ( price - orderPriceOpen ) / Point();
   }else if(positionInfo.PositionType() == POSITION_TYPE_SELL){
         price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
         pipsInGain = ( orderPriceOpen - price ) / Point();
   }

   if( pipsInGain >= minPipsToGoBreakHeaven ){
      return true;
   }else{
      return false;
   }
   
}

void changeTrailingStop(){

   printf("changeTrailingStop");
   /*
   datetime time = iTime(Symbol(), PERIOD_CURRENT, 0);
   string timeS = TimeToString(time, TIME_MINUTES);
   */
   double price, trailingStopInPrice, takeProfitInPrice, oldTrailingStopInPrice;
   int pipsInGain, trailingStopInPoints, stopLossInPoints; //stoploss 
      
   for( int i=PositionsTotal()-1; i>=0; i-- ){ // returns the number of current position
      if( positionInfo.SelectByIndex(i) ){     // selects the position by index for further access to its properties
         if( positionInfo.Symbol() == Symbol() ){
            oldTrailingStopInPrice = positionInfo.StopLoss();           
         }
      }
   }   
   
   bool changeTrailingStop = false;

   if(positionInfo.PositionType() == POSITION_TYPE_BUY){
   
      price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      pipsInGain = ( price - orderPriceOpen ) / Point();
      trailingStopInPoints = pipsInGain * trailingStopFactor;
      trailingStopInPrice = orderPriceOpen + ( trailingStopInPoints * Point() );
      takeProfitInPrice = price + (trailingStopInPoints * Point());
      
      if(oldTrailingStopInPrice < trailingStopInPrice)
         changeTrailingStop = true;
      
   }else if(positionInfo.PositionType() == POSITION_TYPE_SELL){
   
      price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      pipsInGain = ( orderPriceOpen - price ) / Point();
      trailingStopInPoints = pipsInGain * trailingStopFactor;
      trailingStopInPrice = orderPriceOpen - ( trailingStopInPoints * Point() );
      takeProfitInPrice = price - ( trailingStopInPoints * Point() );
      
      if(oldTrailingStopInPrice > trailingStopInPrice)
         changeTrailingStop = true;
   }   

   if( changeTrailingStop )
      cTrade.PositionModify(Symbol(), trailingStopInPrice, takeProfitInPrice);      

}

void goToBreakHeaven(){

   printf("goToBreakHeaven");

   double price, trailingStopInPrice, takeProfitInPrice, oldTrailingStopInPrice;
   int pipsInGain, trailingStopInPoints, stopLossInPoints; //stoploss   
   
   for( int i=PositionsTotal()-1; i>=0; i-- ){ // returns the number of current position
      if( positionInfo.SelectByIndex(i) ){     // selects the position by index for further access to its properties
         if( positionInfo.Symbol() == Symbol() ){
            oldTrailingStopInPrice = positionInfo.StopLoss();  
            takeProfitInPrice = positionInfo.TakeProfit();       
         }
      }
   }
   
   bool goToBreakHeaven = false;

   if(positionInfo.PositionType() == POSITION_TYPE_BUY){
   
      price = SymbolInfoDouble(Symbol(), SYMBOL_BID);      
      pipsInGain = ( price - orderPriceOpen ) / Point();
      trailingStopInPoints = pipsInGain * 0.6;
      trailingStopInPrice = orderPriceOpen + ( 1 * Point() );
      
      if(oldTrailingStopInPrice < trailingStopInPrice)
         goToBreakHeaven = true;
      
   }else if(positionInfo.PositionType() == POSITION_TYPE_SELL){
   
      price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      pipsInGain = ( orderPriceOpen - price ) / Point();
      trailingStopInPrice = orderPriceOpen - ( 1 * Point() );
      
      if(oldTrailingStopInPrice > trailingStopInPrice)
         goToBreakHeaven = true;
   }   

   if(goToBreakHeaven){
      cTrade.PositionModify(Symbol(), trailingStopInPrice, takeProfitInPrice);
      isBreakHeaven = true;   
   }

}

bool isPositionOpen(){

   for( int i=PositionsTotal()-1; i>=0; i-- ){ // returns the number of current position
      if( positionInfo.SelectByIndex(i) ){     // selects the position by index for further access to its properties
         if( positionInfo.Symbol() == Symbol() ){
            return true;            
         }
      }
   }
   
   return false;

}