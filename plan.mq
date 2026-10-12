//+------------------------------------------------------------------+
//|                                            MoneyManagment_V3.mq5 |
//|                       Risk Panel - fixed lot sizing & execution   |
//+------------------------------------------------------------------+
#property copyright "Enhanced Risk Panel"
#property version   "6.00"
#property strict
#property description "پنل مدیریت ریسک - محاسبه حجم بر اساس درصد ریسک با اعتبارسنجی کامل سفارش"

//+------------------------------------------------------------------+
//| ورودی ها                                                          |
//+------------------------------------------------------------------+
input double RiskPercent      = 1.0;            // درصد ریسک از بالانس
input int    StopDistance     = 0;              // فاصله از سایه کندل (پیپ) - 0 = دقیقا پشت سایه
input double MaxLotCap        = 0.0;            // سقف حجم (0 = غیرفعال) - محافظ در برابر کندل خیلی کوچک
input double RewardRatio      = 4.0;            // نسبت ریوارد به ریسک
input int    Slippage         = 10;             // اسلیپیج
input color  BuyColor         = clrDodgerBlue;  // رنگ خطوط خرید
input color  SellColor        = clrTomato;      // رنگ خطوط فروش
input bool   ShowLinesOnChart = true;           // نمایش خطوط روی چارت

//+------------------------------------------------------------------+
//| تنظیمات داخلی (ورودی نیستند - در صورت نیاز همین جا تغییر دهید)   |
//+------------------------------------------------------------------+
const int  MIN_STOP_POINTS        = 1;       // کف مطلق فاصله حد ضرر (پوینت) - فقط برای جلوگیری از صفر شدن
const bool CONFIRM_BEFORE_TRADE   = false;  // true = نمایش پنجره تایید قبل از ارسال (پیش‌فرض خاموش تا اجرا سریع باشد)
const bool ALLOW_MIN_LOT_OVER_RISK= false;   // false = اگر حداقل حجم از ریسک مجاز بیشتر شد، معامله رد شود (ایمن)
const int  MAX_RETRIES            = 3;       // تلاش مجدد در ریکوت
const long MAGIC_NUMBER           = 112233;  // شماره جادویی

//+------------------------------------------------------------------+
//| مشخصات نماد                                                       |
//+------------------------------------------------------------------+
struct SSymbolSpec
  {
   int      digits;
   double   point;
   double   tickSize;
   double   tickValue;
   double   minLot;
   double   maxLot;
   double   lotStep;
   int      lotDigits;
   double   stopLevel;   // بر حسب قیمت
   double   freezeLevel; // بر حسب قیمت
  };

struct STradePlan
  {
   bool     valid;
   string   error;
   double   entry;
   double   sl;
   double   tp;
   double   distance;
   double   lot;
   double   riskRequested;
   double   riskActual;
   double   margin;
  };

string      m_symbol;
SSymbolSpec Spec;

//+------------------------------------------------------------------+
int OnInit()
  {
   m_symbol = _Symbol;

   if(!RefreshSpec())
      Print("[RiskPanel] هشدار: مشخصات نماد هنوز آماده نیست - با رسیدن اولین قیمت دوباره خوانده می شود");

   ObjectsDeleteAll(0, "P_");
   ObjectsDeleteAll(0, "TRADE_");
   CreatePanel();

   EventSetTimer(1);

   PrintFormat("[RiskPanel] آماده | نماد=%s digits=%d point=%.10g tickSize=%.10g tickValue=%.10g",
               m_symbol, Spec.digits, Spec.point, Spec.tickSize, Spec.tickValue);
   PrintFormat("[RiskPanel] حجم: min=%.*f max=%.*f step=%.*f | StopsLevel=%.10g FreezeLevel=%.10g",
               Spec.lotDigits, Spec.minLot, Spec.lotDigits, Spec.maxLot,
               Spec.lotDigits, Spec.lotStep, Spec.stopLevel, Spec.freezeLevel);

   UpdatePanel();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, "P_");
   ObjectsDeleteAll(0, "TRADE_");
   Comment("");
  }

//+------------------------------------------------------------------+
ulong g_lastUpdateMs = 0;

void OnTick()
  {
   // پنل حداکثر 4 بار در ثانیه بروز شود تا بار پردازشی کم بماند
   ulong now = GetTickCount64();
   if(now - g_lastUpdateMs < 250)
      return;
   g_lastUpdateMs = now;
   UpdatePanel();
  }

void OnTimer()
  {
   g_lastUpdateMs = GetTickCount64();
   UpdatePanel();
  }

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam == "P_BUY_BTN")
     {
      ObjectSetInteger(0, "P_BUY_BTN", OBJPROP_STATE, false);
      ChartRedraw();
      ExecuteTrade(ORDER_TYPE_BUY);
     }
   else if(sparam == "P_SELL_BTN")
     {
      ObjectSetInteger(0, "P_SELL_BTN", OBJPROP_STATE, false);
      ChartRedraw();
      ExecuteTrade(ORDER_TYPE_SELL);
     }
   else if(sparam == "P_CLR_BTN")
     {
      ObjectSetInteger(0, "P_CLR_BTN", OBJPROP_STATE, false);
      ObjectsDeleteAll(0, "TRADE_");
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//| خواندن مشخصات نماد - هر بار تازه، نه فقط در OnInit               |
//+------------------------------------------------------------------+
bool RefreshSpec()
  {
   Spec.digits   = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   Spec.point    = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   Spec.tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);

   // TICK_VALUE_LOSS مبنای درست محاسبه ضرر است
   Spec.tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(Spec.tickValue <= 0.0)
      Spec.tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);

   Spec.minLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   Spec.maxLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   Spec.lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

   if(Spec.point <= 0.0)
      return(false);
   if(Spec.tickSize <= 0.0)
      Spec.tickSize = Spec.point;
   if(Spec.lotStep <= 0.0)
      Spec.lotStep = 0.01;
   if(Spec.minLot <= 0.0)
      Spec.minLot = Spec.lotStep;
   if(Spec.maxLot <= 0.0)
      Spec.maxLot = 100.0;

   // تعداد رقم اعشار حجم از روی lotStep - نه عدد ثابت 2
   Spec.lotDigits = (int)MathMax(0.0, MathCeil(-MathLog10(Spec.lotStep) - 1e-9));
   if(Spec.lotDigits > 8)
      Spec.lotDigits = 8;

   Spec.stopLevel   = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL)  * Spec.point;
   Spec.freezeLevel = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL) * Spec.point;

   return(true);
  }

//+------------------------------------------------------------------+
//| ساخت نقشه معامله: قیمت، حد ضرر، حد سود، حجم و اعتبارسنجی         |
//+------------------------------------------------------------------+
STradePlan BuildPlan(ENUM_ORDER_TYPE type)
  {
   STradePlan p;
   p.valid = false;
   p.error = "";
   p.entry = 0; p.sl = 0; p.tp = 0; p.distance = 0;
   p.lot = 0; p.riskRequested = 0; p.riskActual = 0; p.margin = 0;

   if(!RefreshSpec())
     {
      p.error = "مشخصات نماد در دسترس نیست";
      return(p);
     }

   //--- قیمت زنده
   MqlTick tick;
   if(!SymbolInfoTick(m_symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     {
      p.error = "قیمت زنده در دسترس نیست";
      return(p);
     }
   double spread = tick.ask - tick.bid;
   p.entry = (type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;

   //--- کندل قبلی
   double candleHigh = iHigh(m_symbol, PERIOD_CURRENT, 1);
   double candleLow  = iLow(m_symbol, PERIOD_CURRENT, 1);
   if(candleHigh <= 0.0 || candleLow <= 0.0)
     {
      p.error = "تاریخچه کندل آماده نیست";
      return(p);
     }

   //--- حداقل فاصله مجاز: بزرگ‌ترینِ (کف داخلی، حد بروکر + اسپرد)
   double minDist = MathMax((double)MIN_STOP_POINTS * Spec.point,
                            Spec.stopLevel + spread);
   if(Spec.freezeLevel > 0.0)
      minDist = MathMax(minDist, Spec.freezeLevel + spread);
   if(minDist <= 0.0)
      minDist = 10.0 * Spec.point;

   //--- بافر کاربر با همان تعریف نسخه قبلی: 1 پیپ = 10 پوینت
   double buffer = (double)StopDistance * Spec.point * 10.0;

   //--- حد ضرر دقیقا پشت سایه کندل قبلی (بدون دستکاری).
   //    اگر قیمت از سایه عبور کرده یا خیلی نزدیک است، معامله رد می‌شود
   //    و حد ضرر ساختگی (که حجم را منفجر می‌کرد) ساخته نمی‌شود.
   if(type == ORDER_TYPE_BUY)
     {
      p.sl = candleLow - buffer;
      if(p.entry <= p.sl)
        {
         p.error = "قیمت زیر سایه پایین کندل است - حد ضرر معتبر نیست";
         return(p);
        }
     }
   else
     {
      p.sl = candleHigh + buffer;
      if(p.entry >= p.sl)
        {
         p.error = "قیمت بالای سایه بالای کندل است - حد ضرر معتبر نیست";
         return(p);
        }
     }

   p.entry = NormalizeDouble(p.entry, Spec.digits);
   p.sl    = NormalizeDouble(p.sl,    Spec.digits);
   p.distance = MathAbs(p.entry - p.sl);

   if(p.distance < minDist - Spec.point * 0.5)
     {
      p.error = StringFormat("فاصله تا سایه (%.1f پوینت) کمتر از حداقل بروکر (%.1f پوینت) است",
                             p.distance / Spec.point, minDist / Spec.point);
      return(p);
     }

   //--- حد سود
   double tpDist = MathMax(p.distance * RewardRatio, minDist);
   p.tp = (type == ORDER_TYPE_BUY) ? p.entry + tpDist : p.entry - tpDist;
   p.tp = NormalizeDouble(p.tp, Spec.digits);

   //--- مبلغ ریسک
   p.riskRequested = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
   if(p.riskRequested <= 0.0)
     {
      p.error = "مبلغ ریسک صفر است (موجودی یا درصد ریسک را بررسی کنید)";
      return(p);
     }

   //--- ضرر یک لات کامل: اول از خود بروکر، در صورت خطا از tickValue
   double lossPerLot = 0.0;
   double calc = 0.0;
   if(OrderCalcProfit(type, m_symbol, 1.0, p.entry, p.sl, calc) && calc != 0.0)
      lossPerLot = MathAbs(calc);
   else
      lossPerLot = p.distance / Spec.tickSize * Spec.tickValue;

   if(lossPerLot <= 0.0)
     {
      p.error = "محاسبه ارزش هر لات ممکن نیست";
      return(p);
     }

   //--- حجم
   double raw = p.riskRequested / lossPerLot;
   double lot = MathFloor(raw / Spec.lotStep + 1e-8) * Spec.lotStep;
   lot = NormalizeDouble(lot, Spec.lotDigits);

   if(MaxLotCap > 0.0 && lot > MaxLotCap)
     {
      p.lot = lot;
      p.error = StringFormat("حجم محاسبه‌شده %.*f از سقف تعیین‌شده %.*f بیشتر است (کندل خیلی کوچک)",
                             Spec.lotDigits, lot, Spec.lotDigits, MaxLotCap);
      return(p);
     }

   if(lot > Spec.maxLot)
     {
      p.lot = lot;
      p.error = StringFormat("حجم لازم %.*f از سقف مجاز %.*f بیشتر است - ریسک %.1f%% با این حد ضرر قابل اجرا نیست",
                             Spec.lotDigits, lot, Spec.lotDigits, Spec.maxLot, RiskPercent);
      return(p);
     }

   if(lot < Spec.minLot)
     {
      double minRisk = Spec.minLot * lossPerLot;
      if(!ALLOW_MIN_LOT_OVER_RISK)
        {
         p.lot = Spec.minLot;
         p.error = StringFormat("حداقل حجم %.*f معادل ریسک $%.2f است، بیشتر از ریسک مجاز $%.2f",
                                Spec.lotDigits, Spec.minLot, minRisk, p.riskRequested);
         return(p);
        }
      lot = Spec.minLot;
     }

   p.lot = lot;

   //--- ریسک واقعی با حجم نهایی
   if(OrderCalcProfit(type, m_symbol, p.lot, p.entry, p.sl, calc))
      p.riskActual = MathAbs(calc);
   else
      p.riskActual = p.lot * lossPerLot;

   //--- کنترل مارجین
   double needMargin = 0.0;
   if(OrderCalcMargin(type, m_symbol, p.lot, p.entry, needMargin))
     {
      p.margin = needMargin;
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double usable     = freeMargin * 0.95;   // 5٪ حاشیه امنیت برای تغییر قیمت/اسپرد

      if(needMargin > usable)
        {
         //--- حد ضرر نزدیک => حجم بزرگ => مارجین بیشتر از موجودی.
         //    حجم را به بیشترین مقداری که مارجین اجازه می‌دهد کاهش بده
         //    (ریسک واقعی کمتر از ریسک درخواستی می‌شود، که امن است)
         double scaled = p.lot * usable / needMargin;
         double newLot = MathFloor(scaled / Spec.lotStep + 1e-8) * Spec.lotStep;
         newLot = NormalizeDouble(newLot, Spec.lotDigits);

         if(newLot < Spec.minLot)
           {
            p.error = StringFormat("مارجین کافی نیست: نیاز $%.2f | آزاد $%.2f (حتی حداقل حجم هم ممکن نیست)",
                                   needMargin, freeMargin);
            return(p);
           }

         PrintFormat("[RiskPanel] مارجین کافی نیست برای حجم %.*f؛ حجم به %.*f کاهش یافت",
                     Spec.lotDigits, p.lot, Spec.lotDigits, newLot);

         p.lot = newLot;
         if(OrderCalcMargin(type, m_symbol, p.lot, p.entry, needMargin))
            p.margin = needMargin;

         if(OrderCalcProfit(type, m_symbol, p.lot, p.entry, p.sl, calc))
            p.riskActual = MathAbs(calc);
         else
            p.riskActual = p.lot * lossPerLot;

         if(p.margin > usable)
           {
            p.error = StringFormat("مارجین کافی نیست: نیاز $%.2f | آزاد $%.2f", p.margin, freeMargin);
            return(p);
           }
        }
     }

   p.valid = true;
   return(p);
  }

//+------------------------------------------------------------------+
//| آیا نقشه جدید با نقشه تاییدشده یکی است؟ (حجم و حد ضرر)            |
//+------------------------------------------------------------------+
bool PlanMatches(const STradePlan &a, const STradePlan &b)
  {
   // فقط تغییر حد ضرر (یعنی کندل جدید شروع شده) معامله را لغو می‌کند.
   // حجم از ریسک ثابت محاسبه می‌شود و با حرکت جزئی قیمت کمی تغییر می‌کند؛
   // ریسک واقعی همیشه از روی حجم نهایی محاسبه می‌شود، پس مقایسه حجم لازم نیست.
   if(MathAbs(a.sl - b.sl) > Spec.point * 0.5)
      return(false);
   // اگر حجم بیش از 50٪ تغییر کرده (حرکت شدید قیمت) هم لغو شود
   double tol = MathMax(Spec.lotStep * 2.0, a.lot * 0.50);
   if(MathAbs(a.lot - b.lot) > tol + 1e-9)
      return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| اجرای معامله                                                      |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     { Alert("معاملات در ترمینال غیرفعال است (AutoTrading)"); return; }

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     { Alert("معاملات برای این اکسپرت مجاز نیست"); return; }

   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     { Alert("معاملات اکسپرت از سمت سرور مجاز نیست"); return; }

   long tradeMode = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
     { Alert("معامله روی این نماد غیرفعال است"); return; }
   if(tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
     { Alert("این نماد فقط اجازه بستن معامله دارد"); return; }
   if(type == ORDER_TYPE_BUY && tradeMode == SYMBOL_TRADE_MODE_SHORTONLY)
     { Alert("روی این نماد فقط فروش مجاز است"); return; }
   if(type == ORDER_TYPE_SELL && tradeMode == SYMBOL_TRADE_MODE_LONGONLY)
     { Alert("روی این نماد فقط خرید مجاز است"); return; }

   //--- نقشه اولیه: حجم و حد ضرر همین نقشه مبنای مقایسه بعد از تایید است
   STradePlan first = BuildPlan(type);
   if(!first.valid)
     {
      Alert("امکان اجرا نیست: " + first.error);
      Print("[RiskPanel] رد شد: ", first.error);
      return;
     }

   //--- تایید اختیاری (پیش‌فرض خاموش تا اجرا سریع باشد)
   if(CONFIRM_BEFORE_TRADE)
     {
      STradePlan preview = first;
      string txt = preview.valid
                   ? StringFormat("%s\nورود: %.*f\nحد ضرر: %.*f\nحد سود: %.*f\nحجم: %.*f\nریسک: $%.2f",
                                  (type == ORDER_TYPE_BUY) ? "خرید" : "فروش",
                                  Spec.digits, preview.entry, Spec.digits, preview.sl,
                                  Spec.digits, preview.tp, Spec.lotDigits, preview.lot,
                                  preview.riskActual)
                   : ("امکان اجرا نیست: " + preview.error);

      if(!preview.valid)
        { Alert(txt); return; }

      if(MessageBox(txt + "\n\nمعامله ارسال شود؟", "تایید معامله", MB_YESNO | MB_ICONQUESTION) != IDYES)
        { Print("[RiskPanel] معامله توسط کاربر لغو شد"); return; }
     }

   //--- نقشه نهایی با قیمت لحظه ارسال (بعد از تایید دوباره ساخته می‌شود)
   STradePlan plan = BuildPlan(type);
   if(!plan.valid)
     {
      Alert("امکان اجرا نیست: " + plan.error);
      Print("[RiskPanel] رد شد: ", plan.error);
      return;
     }

   //--- اگر بعد از تایید کندل عوض شده یا حجم/حد ضرر تغییر کرده، ارسال نکن
   if(!PlanMatches(first, plan))
     {
      Alert("حد ضرر یا حجم بعد از تایید تغییر کرد (احتمالا کندل جدید شروع شد). دوباره تلاش کنید.");
      PrintFormat("[RiskPanel] لغو: حجم %.*f -> %.*f | SL %.*f -> %.*f",
                  Spec.lotDigits, first.lot, Spec.lotDigits, plan.lot,
                  Spec.digits, first.sl, Spec.digits, plan.sl);
      return;
     }

   PrintFormat("[RiskPanel] %s | ورود=%.*f SL=%.*f TP=%.*f | فاصله=%.*f | حجم=%.*f | ریسک درخواستی=$%.2f واقعی=$%.2f | مارجین=$%.2f",
               (type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
               Spec.digits, plan.entry, Spec.digits, plan.sl, Spec.digits, plan.tp,
               Spec.digits, plan.distance, Spec.lotDigits, plan.lot,
               plan.riskRequested, plan.riskActual, plan.margin);

   //--- اطلاعات عیب‌یابی حد ضرر: کندل مبنا، بافر و فاصله به پوینت
   PrintFormat("[RiskPanel] مبنای SL: کندل قبلی(%s) High=%.*f Low=%.*f | StopDistance=%d (بافر=%.1f پوینت) | فاصله SL=%.1f پوینت | تایم‌فریم=%s",
               TimeToString(iTime(m_symbol, PERIOD_CURRENT, 1)),
               Spec.digits, iHigh(m_symbol, PERIOD_CURRENT, 1),
               Spec.digits, iLow(m_symbol, PERIOD_CURRENT, 1),
               StopDistance, (double)StopDistance * 10.0,
               plan.distance / Spec.point, EnumToString((ENUM_TIMEFRAMES)_Period));

   //--- حالت های پرکردن قابل امتحان
   ENUM_ORDER_TYPE_FILLING fillings[3];
   int fillCount = BuildFillingList(fillings);

   MqlTradeRequest request;
   MqlTradeResult  result;
   MqlTradeCheckResult check;

   bool sent           = false;
   int  fillIdx        = 0;
   bool stopsInRequest = true;   // بعضی بروکرها SL/TP را در خود سفارش قبول نمی کنند
   int  maxTry         = (MAX_RETRIES < 1) ? 1 : MAX_RETRIES;
   int  guard          = 0;      // محافظ حلقه بی نهایت

   for(int attempt = 0; attempt < maxTry && !sent; attempt++)
     {
      if(++guard > maxTry + 5)
        { Alert("ارسال سفارش ممکن نشد"); return; }

      if(attempt > 0)
        {
         plan = BuildPlan(type);          // قیمت تازه در هر تلاش
         if(!plan.valid)
           { Alert("امکان اجرا نیست: " + plan.error); return; }
         if(!PlanMatches(first, plan))
           { Alert("حجم یا حد ضرر در ریتری تغییر کرد - سفارش لغو شد"); return; }
        }

      ZeroMemory(request);
      ZeroMemory(result);
      ZeroMemory(check);

      request.action       = TRADE_ACTION_DEAL;
      request.symbol       = m_symbol;
      request.volume       = plan.lot;
      request.type         = type;
      request.price        = plan.entry;
      request.sl           = stopsInRequest ? plan.sl : 0.0;
      request.tp           = stopsInRequest ? plan.tp : 0.0;
      request.deviation    = Slippage;
      request.magic        = MAGIC_NUMBER;
      request.comment      = StringFormat("RP-R%.2f-RR%.1f", RiskPercent, RewardRatio);
      request.type_filling = fillings[fillIdx];

      //--- بررسی قبل از ارسال: خطا را قبل از سرور نشان می‌دهد
      if(!OrderCheck(request, check))
        {
         PrintFormat("[RiskPanel] OrderCheck ناموفق: %u - %s | %s",
                     check.retcode, RetcodeText(check.retcode), check.comment);

         if(check.retcode == TRADE_RETCODE_INVALID_FILL && fillIdx + 1 < fillCount)
           { fillIdx++; attempt--; continue; }

         if(check.retcode == TRADE_RETCODE_INVALID_STOPS && stopsInRequest)
           {
            Print("[RiskPanel] بروکر SL/TP را در سفارش قبول نکرد - بعد از باز شدن اعمال می شود");
            stopsInRequest = false;
            attempt--;
            continue;
           }

         Alert("سفارش نامعتبر: " + RetcodeText(check.retcode));
         return;
        }

      if(!OrderSend(request, result))
         PrintFormat("[RiskPanel] OrderSend خطا | retcode=%u (%s) | last_error=%d",
                     result.retcode, RetcodeText(result.retcode), GetLastError());

      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED ||
         result.retcode == TRADE_RETCODE_DONE_PARTIAL)
        {
         sent = true;
         PrintFormat("[RiskPanel] موفق | deal=%I64u order=%I64u حجم=%.*f قیمت=%.*f",
                     result.deal, result.order, Spec.lotDigits, result.volume,
                     Spec.digits, result.price);
         PlaySound("ok.wav");

         if(!stopsInRequest)
            ApplyStopsAfterFill(plan.sl, plan.tp);

         //--- ریسک واقعی بر اساس قیمت پر شدن (نه قیمت درخواستی)
         double fillPrice = (result.price > 0.0) ? result.price : plan.entry;
         double fillRisk  = plan.riskActual;
         double fcalc = 0.0;
         if(OrderCalcProfit(type, m_symbol, plan.lot, fillPrice, plan.sl, fcalc))
            fillRisk = MathAbs(fcalc);
         PrintFormat("[RiskPanel] ریسک واقعی با قیمت پر شدن: $%.2f (درخواستی $%.2f)",
                     fillRisk, plan.riskRequested);

         if(ShowLinesOnChart)
            DrawTradeLines(type, fillPrice, plan.sl, plan.tp, plan.lot, fillRisk);
         break;
        }

      //--- خطاهای قابل تلاش مجدد
      if(result.retcode == TRADE_RETCODE_REQUOTE ||
         result.retcode == TRADE_RETCODE_PRICE_CHANGED ||
         result.retcode == TRADE_RETCODE_PRICE_OFF)
        {
         Print("[RiskPanel] ریکوت - تلاش مجدد ", attempt + 1);
         continue;
        }

      if(result.retcode == TRADE_RETCODE_INVALID_FILL && fillIdx + 1 < fillCount)
        {
         fillIdx++;
         attempt--;
         continue;
        }

      Alert(StringFormat("خطا در ارسال سفارش: %u - %s", result.retcode, RetcodeText(result.retcode)));
      return;
     }

   if(!sent)
      Alert("سفارش پس از چند تلاش ارسال نشد (ریکوت مکرر)");
  }

//+------------------------------------------------------------------+
//| اعمال SL/TP بعد از باز شدن پوزیشن                                 |
//+------------------------------------------------------------------+
void ApplyStopsAfterFill(double sl, double tp)
  {
   //--- جدیدترین پوزیشن همین نماد و همین مجیک را پیدا کن
   ulong  newest   = 0;
   long   newestMs = -1;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER)
         continue;
      long ms = PositionGetInteger(POSITION_TIME_MSC);
      if(ms > newestMs)
        { newestMs = ms; newest = t; }
     }

   for(int k = 0; k < 1 && newest != 0; k++)
     {
      ulong ticket = newest;

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = m_symbol;
      req.position = ticket;
      req.sl       = NormalizeDouble(sl, Spec.digits);
      req.tp       = NormalizeDouble(tp, Spec.digits);

      if(!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE)
         PrintFormat("[RiskPanel] اعمال SL/TP ناموفق روی %I64u | %u - %s",
                     ticket, res.retcode, RetcodeText(res.retcode));
      else
         PrintFormat("[RiskPanel] SL/TP روی پوزیشن %I64u اعمال شد", ticket);
      return;
     }
  }

//+------------------------------------------------------------------+
//| لیست حالت های پرکردن بر اساس مشخصات نماد                          |
//+------------------------------------------------------------------+
int BuildFillingList(ENUM_ORDER_TYPE_FILLING &list[])
  {
   long allowed = SymbolInfoInteger(m_symbol, SYMBOL_FILLING_MODE);
   long exeMode = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_EXEMODE);
   int  n = 0;

   if((allowed & SYMBOL_FILLING_IOC) != 0) list[n++] = ORDER_FILLING_IOC;
   if((allowed & SYMBOL_FILLING_FOK) != 0) list[n++] = ORDER_FILLING_FOK;

   // فقط اجرای Market/Instant اجازه RETURN دارد
   if(n < 3 && exeMode != SYMBOL_TRADE_EXECUTION_MARKET)
      list[n++] = ORDER_FILLING_RETURN;

   if(n == 0)
     {
      list[0] = ORDER_FILLING_IOC;
      n = 1;
     }
   return(n);
  }

//+------------------------------------------------------------------+
//| ترجمه کدهای خطای معاملاتی                                         |
//+------------------------------------------------------------------+
string RetcodeText(uint code)
  {
   switch(code)
     {
      case TRADE_RETCODE_DONE:            return("انجام شد");
      case TRADE_RETCODE_REQUOTE:         return("ریکوت - قیمت تغییر کرد");
      case TRADE_RETCODE_REJECT:          return("درخواست رد شد");
      case TRADE_RETCODE_INVALID:         return("درخواست نامعتبر");
      case TRADE_RETCODE_INVALID_VOLUME:  return("حجم نامعتبر");
      case TRADE_RETCODE_INVALID_PRICE:   return("قیمت نامعتبر");
      case TRADE_RETCODE_INVALID_STOPS:   return("حد ضرر یا حد سود نامعتبر (خیلی نزدیک به قیمت)");
      case TRADE_RETCODE_TRADE_DISABLED:  return("معاملات غیرفعال است");
      case TRADE_RETCODE_MARKET_CLOSED:   return("بازار بسته است");
      case TRADE_RETCODE_NO_MONEY:        return("موجودی/مارجین کافی نیست");
      case TRADE_RETCODE_PRICE_CHANGED:   return("قیمت تغییر کرد");
      case TRADE_RETCODE_PRICE_OFF:       return("قیمت لحظه ای در دسترس نیست");
      case TRADE_RETCODE_INVALID_EXPIRATION: return("تاریخ انقضای نامعتبر");
      case TRADE_RETCODE_ORDER_CHANGED:   return("وضعیت سفارش تغییر کرد");
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return("درخواست بیش از حد");
      case TRADE_RETCODE_INVALID_FILL:    return("حالت پرکردن سفارش پشتیبانی نمی شود");
      case TRADE_RETCODE_CONNECTION:      return("ارتباط با سرور برقرار نیست");
      case TRADE_RETCODE_LIMIT_VOLUME:    return("سقف حجم مجاز نماد");
      case TRADE_RETCODE_POSITION_CLOSED: return("پوزیشن بسته شده است");
      default:                            return("کد " + IntegerToString(code));
     }
  }

//+------------------------------------------------------------------+
//| بروزرسانی پنل                                                     |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   STradePlan b = BuildPlan(ORDER_TYPE_BUY);
   STradePlan s = BuildPlan(ORDER_TYPE_SELL);

   double riskUSD = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);

   ObjectSetString(0, "P_INFO", OBJPROP_TEXT, StringFormat("Risk: $%.2f (%.2f%%)", riskUSD, RiskPercent));
   ObjectSetString(0, "P_LOT_BUY",  OBJPROP_TEXT,
                   b.valid ? StringFormat("Buy Lot: %.*f", Spec.lotDigits, b.lot)  : "Buy Lot: --");
   ObjectSetString(0, "P_LOT_SELL", OBJPROP_TEXT,
                   s.valid ? StringFormat("Sell Lot: %.*f", Spec.lotDigits, s.lot) : "Sell Lot: --");

   string warn = "";
   if(!b.valid) warn = b.error;
   else if(!s.valid) warn = s.error;
   ObjectSetString(0, "P_WARN", OBJPROP_TEXT, warn);
   ObjectSetInteger(0, "P_WARN", OBJPROP_COLOR, (warn == "") ? clrGray : clrOrangeRed);

   string c = "Risk Panel V3\n====================\n";
   c += StringFormat("Balance: $%.2f | Equity: $%.2f\n",
                     AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY));
   c += StringFormat("Risk: $%.2f (%.2f%%)  R:R 1:%.1f\n", riskUSD, RiskPercent, RewardRatio);
   c += StringFormat("MinStop: %d pts | StopsLevel: %.*f\n", MIN_STOP_POINTS, Spec.digits, Spec.stopLevel);

   c += "\nBUY:\n";
   if(b.valid)
      c += StringFormat("Entry %.*f | SL %.*f | TP %.*f\nLot %.*f | Risk $%.2f | Margin $%.2f\n",
                        Spec.digits, b.entry, Spec.digits, b.sl, Spec.digits, b.tp,
                        Spec.lotDigits, b.lot, b.riskActual, b.margin);
   else
      c += b.error + "\n";

   c += "\nSELL:\n";
   if(s.valid)
      c += StringFormat("Entry %.*f | SL %.*f | TP %.*f\nLot %.*f | Risk $%.2f | Margin $%.2f",
                        Spec.digits, s.entry, Spec.digits, s.sl, Spec.digits, s.tp,
                        Spec.lotDigits, s.lot, s.riskActual, s.margin);
   else
      c += s.error;

   Comment(c);
  }

//+------------------------------------------------------------------+
void DrawTradeLines(ENUM_ORDER_TYPE type, double entry, double sl, double tp, double lot, double riskUSD)
  {
   string prefix    = (type == ORDER_TYPE_BUY) ? "TRADE_BUY_" : "TRADE_SELL_";
   string tradeType = (type == ORDER_TYPE_BUY) ? "BUY" : "SELL";

   ObjectsDeleteAll(0, prefix);

   CreateHorizontalLine(prefix + "ENTRY", entry, clrWhite, 2, STYLE_SOLID,
                        StringFormat("%s Entry %.*f | Lot %.*f", tradeType, Spec.digits, entry, Spec.lotDigits, lot));
   CreateHorizontalLine(prefix + "STOP", sl, clrRed, 2, STYLE_SOLID,
                        StringFormat("SL %.*f | Risk $%.2f", Spec.digits, sl, riskUSD));
   CreateHorizontalLine(prefix + "TARGET", tp, clrLime, 2, STYLE_SOLID,
                        StringFormat("TP %.*f | R:R 1:%.1f", Spec.digits, tp, RewardRatio));

   datetime t1 = TimeCurrent() - PeriodSeconds() * 10;
   datetime t2 = TimeCurrent() + PeriodSeconds() * 10;

   if(type == ORDER_TYPE_BUY)
     {
      CreateRectangle(prefix + "RISK_ZONE",   t1, sl,    t2, entry, clrRed,  STYLE_DASHDOTDOT, 1, true);
      CreateRectangle(prefix + "PROFIT_ZONE", t1, entry, t2, tp,    clrLime, STYLE_DASHDOTDOT, 1, true);
     }
   else
     {
      CreateRectangle(prefix + "RISK_ZONE",   t1, entry, t2, sl,    clrRed,  STYLE_DASHDOTDOT, 1, true);
      CreateRectangle(prefix + "PROFIT_ZONE", t1, tp,    t2, entry, clrLime, STYLE_DASHDOTDOT, 1, true);
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
void CreatePanel()
  {
   CreateRect("P_BG", 10, 10, 210, 235, C'30,30,40', clrGray);

   CreateLabel("P_TITLE",     "RISK PANEL V3",  20, 20,  clrGold,   10, "Arial Bold");
   CreateLabel("P_INFO",      "Risk: $--",      20, 45,  clrWhite,   9);
   CreateLabel("P_LOT_BUY",   "Buy Lot: --",    20, 65,  clrLime,    9);
   CreateLabel("P_LOT_SELL",  "Sell Lot: --",   20, 85,  clrOrange,  9);

   CreateBtn("P_BUY_BTN",  "BUY NOW",     15, 110, 90, 40, clrWhite, clrGreen);
   CreateBtn("P_SELL_BTN", "SELL NOW",   115, 110, 90, 40, clrWhite, clrRed);
   CreateBtn("P_CLR_BTN",  "Clear Lines", 15, 160, 190, 28, clrWhite, clrGray);

   CreateLabel("P_RISK_INFO", "Risk: " + DoubleToString(RiskPercent, 2) + "%", 20,  196, clrYellow, 8);
   CreateLabel("P_RR_INFO",   "R:R 1:" + DoubleToString(RewardRatio, 1),      120, 196, clrCyan,   8);
   CreateLabel("P_WARN",      "",                                             20,  214, clrGray,   8);
  }

//+------------------------------------------------------------------+
void CreateHorizontalLine(string name, double price, color clr, int width, ENUM_LINE_STYLE style, string text = "")
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   if(text != "")
      ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bg, color border)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int sz, string font = "Arial")
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, sz);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
void CreateBtn(string name, string text, int x, int y, int w, int h, color txt, color bg)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txt);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

//+------------------------------------------------------------------+
void CreateRectangle(string name, datetime time1, double price1, datetime time2, double price2,
                     color clr, ENUM_LINE_STYLE style, int width, bool fill = false)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }
//+------------------------------------------------------------------+