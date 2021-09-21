//+------------------------------------------------------------------+
//|                                                    ay-object.mq4 |
//|                         Copyright © 2011, ahmad.yani@hotmail.com |
//|                                              eyesfx.blogspot.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2011, ahmad.yani@hotmail.com"
#property link      "eyesfx.blogspot.com"

//+------------------------------------------------------------------+
//| createRect                                                       |
//+------------------------------------------------------------------+   
void createRect(string objname, double p1, datetime t1, double p2, 
   datetime t2, color clr, bool back=true)
{

   objname = gsPref + objname;
   if(ObjectFind(objname) != 0)    
      ObjectCreate(objname, OBJ_RECTANGLE, 0, 0, 0, 0, 0);
   
   ObjectSet(objname, OBJPROP_PRICE1, p1);
   ObjectSet(objname, OBJPROP_TIME1,  t1);
   ObjectSet(objname, OBJPROP_PRICE2, p2);
   ObjectSet(objname, OBJPROP_TIME2,  t2);
   ObjectSet(objname, OBJPROP_COLOR,  clr);
   ObjectSet(objname, OBJPROP_BACK,   back);
}  
//+------------------------------------------------------------------+
//| createArw                                                        |
//+------------------------------------------------------------------+ 
void createArw(string objname, double p1, datetime t1, int ac, 
   color clr)
{
   objname = gsPref + objname;
   if(ObjectFind(objname) != 0)    
      ObjectCreate(objname, OBJ_ARROW, 0, 0, 0, 0, 0);
   
   ObjectSet(objname, OBJPROP_PRICE1,     p1);
   ObjectSet(objname, OBJPROP_TIME1,      t1);  
   ObjectSet(objname, OBJPROP_ARROWCODE,  ac);  
   ObjectSet(objname, OBJPROP_COLOR,      clr);  
   
}
//+------------------------------------------------------------------+
//| createText                                                       |
//+------------------------------------------------------------------+
void createText(string name, datetime t, double p, string text
   , int size=8, string font="Arial", color c=White, int winid=0)
{
   name = gsPref + name;
   
   if (ObjectFind(name) != winid)
      ObjectCreate (name,OBJ_TEXT,winid,0,0);
   
   ObjectSet    (name,OBJPROP_TIME1,  t);
   ObjectSet    (name,OBJPROP_PRICE1, p);
   ObjectSetText(name,text,size,font, c);

}

void lblCreate(string name,int x,int y, string text, int corner =0
   , color c=Silver, int size=8, string font="Tahoma")
{
   
   name = gsPref + name;
   ObjectCreate (name,OBJ_LABEL,0,0,0);
   ObjectSet    (name,OBJPROP_CORNER,corner);
   ObjectSet    (name,OBJPROP_XDISTANCE,x);
   ObjectSet    (name,OBJPROP_YDISTANCE,y);
   ObjectSetText(name,text,size,font,c);
} 

//+------------------------------------------------------------------+
//| createTl                                                         |
//+------------------------------------------------------------------+ 
void createTl(string tlname, datetime t1, double v1, 
     datetime t2, double v2, color tlColor, int style = STYLE_SOLID, 
     int width = 1, bool back=true, bool ray=false, string desc="")
{
   tlname = gsPref + tlname;
   if(ObjectFind(tlname) != 0)
   {
      ObjectCreate(
            tlname
            , OBJ_TREND
            , 0
            , t1
            , v1
            , t2
            , v2
            );      
   }else
   {
      ObjectMove(tlname, 0, t1, v1);   
      ObjectMove(tlname, 1, t2, v2);
   }
   ObjectSet(tlname, OBJPROP_COLOR, tlColor);
   ObjectSet(tlname, OBJPROP_RAY,   ray);
   ObjectSet(tlname, OBJPROP_STYLE, style);
   ObjectSet(tlname, OBJPROP_WIDTH, width);
   ObjectSet(tlname, OBJPROP_BACK,  back);
   ObjectSetText(tlname, desc);
} 

//+------------------------------------------------------------------+
//| delObjs function                                                 |
//+------------------------------------------------------------------+
void delObjs(string s="")
{
   int objs = ObjectsTotal();
   if (StringLen(s) == 0) s = gsPref;
   
   string name;
   for(int cnt=ObjectsTotal()-1;cnt>=0;cnt--)
   {
      name=ObjectName(cnt);
      if (StringSubstr(name,0,StringLen(s)) == s)       
         ObjectDelete(name); 
   }   
} 
// taken from stdlib.mp4 library  
//+------------------------------------------------------------------+
//| convert red, green and blue values to color                      |
//+------------------------------------------------------------------+
int RGB(int red_value,int green_value,int blue_value)
{
   //---- check parameters
   if(red_value<0)     red_value   = 0;
   if(red_value>255)   red_value   = 255;
   if(green_value<0)   green_value = 0;
   if(green_value>255) green_value = 255;
   if(blue_value<0)    blue_value  = 0;
   if(blue_value>255)  blue_value  = 255;
   //----
   green_value<<=8;
   blue_value<<=16;
   return(red_value+green_value+blue_value);
}
//+------------------------------------------------------------------+
//| convert color to red, green and blue values                      |
//+------------------------------------------------------------------+  
void intToRGB(int clr, int &ired, int &igreen, int &iblue )
{   
   ired   = (clr % 0x100); 
   igreen = (clr % 0x10000 / 0x100);     
   iblue  = (clr % 0x1000000 / 0x10000);            
}  
//+------------------------------------------------------------------+
//| getNextGradColor                                                 |
//+------------------------------------------------------------------+ 
void getNextGradColor(int iclr, int &ired, int &igreen, int &iblue, bool reset = false)
{
    
   static bool minred, mingreen, minblue;
  
   if (reset==true) { minred = false; mingreen=false; minblue = false; }
      
   if ( ired   + iclr > 255 )  minred   = true;
   if ( ired   - iclr < 0 )    minred   = false;         
   if ( igreen + iclr > 255 )  mingreen = true;
   if ( igreen - iclr < 0 )    mingreen = false;         
   if ( iblue  + iclr > 255 )  minblue  = true;
   if ( iblue  - iclr < 0 )    minblue  = false;
                                      
   if ( minred )   ired   -= iclr;  else ired   +=iclr;         
   if ( mingreen ) igreen -= iclr;  else igreen +=iclr;         
   if ( minblue )  iblue  -= iclr;  else iblue  +=iclr; 
   /*
   
   if ( ired + iclr   > 255 ) ired   = (ired + iclr) - 255; 
   else ired += iclr;
   
   if ( igreen + iclr > 255 ) igreen = (igreen + iclr) - 255; 
   else igreen += iclr;
   
   if ( iblue + iclr  > 255 ) iblue  = (iblue + iclr) - 255; 
   else iblue += iclr;
   */
}


