//+------------------------------------------------------------------+
//|                                              BolsaExpAdvisor.mq5 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Zmq/Zmq.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\Trade.mqh>

extern string PROJECT_NAME = "BolsaAPI";
extern string ZEROMQ_PROTOCOL = "tcp";
extern string HOSTNAME = "*";
extern int REP_PORT = 5555;
extern int MILLISECOND_TIMER = 1; 

extern string t0 = "--- Trading Parameters ---";
extern int MagicNumber = 123456;
extern int MaximumSlippage = 3;


// CREATE ZeroMQ Context
Context context(PROJECT_NAME);

// CREATE ZMQ_REP SOCKET
Socket repSocket(context,ZMQ_REP);

// VARIABLES FOR LATER
uchar myData[];
ZmqMsg request;

CTrade trade;

int OnInit()
{
    EventSetMillisecondTimer(MILLISECOND_TIMER); 

    Print("Initializing - Binding MT5 Server to Socket on Port " + IntegerToString(REP_PORT) + "..");

    repSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT));

    // Timeout after socket has been closed
    repSocket.setLinger(1000);  

    //Ammount of messages to buffer in RAM before blocking the socket
    repSocket.setSendHighWaterMark(5);     

    return(INIT_SUCCEEDED);
}
  
void OnDeinit(const int reason)
{
    Print("Closing - Unbinding MT5 Server from Socket on Port " + IntegerToString(REP_PORT) + "..");
    repSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT));
}

void OnTimer()
{   
    // Get client's response, but don't wait.
    repSocket.recv(request,true);
    
    MessageHandler(request);
}

void MessageHandler(ZmqMsg &localRequest)
{
    ZmqMsg reply;
    
    string components[];
    
    if(localRequest.size() > 0) {
        ArrayResize(myData, localRequest.size());
        localRequest.getData(myData);
        string dataStr = CharArrayToString(myData);
        
        ParseZmqMessage(dataStr, components);

        InterpretZmqMessage(components);
    }
}

void InterpretZmqMessage(string& compArray[])
{
    Print("ZMQ: Interpreting Message..");
    
    ZmqMsg msg("[SERVER] Error ocurred on metatrader");
    string bolsa_response = "N/A";
    
    if (ArraySize(compArray) > 1 && compArray[0] == "RATES") {
         bolsa_response = GetInfoFromStock(compArray[1]);
    }
    repSocket.send(bolsa_response, false);
}

void ParseZmqMessage(string& message, string& retArray[]) 
{   
    Print("Parsing: " + message);
    
    string sep = "|";
    ushort u_sep = StringGetCharacter(sep,0);
    
    int splits = StringSplit(message, u_sep, retArray);
    
    for(int i = 0; i < splits; i++) {
        Print(IntegerToString(i) + ") " + retArray[i]);
    }
}

string GetInfoFromStock(string stock)
{
    MqlTick last_tick;
    double max = SymbolInfoDouble(stock, SYMBOL_LASTHIGH); 
    double min = SymbolInfoDouble(stock, SYMBOL_LASTLOW);
    SymbolInfoTick(stock,last_tick);    
    double bid = last_tick.bid;
    double ask = last_tick.ask;

    MarketBookAdd(stock);
    return(StringFormat("%.2f,%.2f,%.2f,%.2f", bid, ask, max, min));
}