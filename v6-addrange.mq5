//@version=5
indicator("Pin Bar + SMA Confirmation", shorttitle="Pin Bar", overlay=true, max_boxes_count=500)

// ======================= Inputs =======================
grpPin = "Pin bar shape"
wickRatio = input.float(2.0, "Long wick / body (min)", minval=1.0, step=0.1, tooltip="The long wick must be at least this many times the body.")
wickPct   = input.float(60.0, "Long wick % of candle range (min)", minval=40, maxval=95, step=1, tooltip="The long wick must take at least this part of the full candle (high - low).")
oppPct    = input.float(20.0, "Opposite wick % of range (max)", minval=0, maxval=50, step=1, tooltip="The short wick on the other side must be small.")

grpSize = "Pin bar size"
minAtr  = input.float(0.8, "Min size (x ATR14)", minval=0, step=0.1, tooltip="Candle range (high - low) must be at least this multiple of ATR. 0 = off.")
maxAtr  = input.float(0.0, "Max size (x ATR14, 0 = off)", minval=0, step=0.1, tooltip="Rejects huge candles. 0 = off.")
minPts  = input.float(0.0, "Min size (points)", minval=0, step=1, tooltip="Extra manual minimum for the candle range, in points. 0 = off.")

grpSma = "SMA confirmation"
smaMode = input.string("Close on side", "SMA confirmation", options=["Off", "Close on side", "Wick touches SMA"], tooltip="Off: no SMA filter.\nClose on side: bullish pin bar closes above the SMA, bearish closes below it.\nWick touches SMA: the long wick pierces the SMA and the candle closes back on the trend side (a rejection of the SMA).")
maLen   = input.int(7, "SMA length", minval=1)
showMA  = input.bool(false, "Plot the SMA")

grpRule = "Extra rules"
rejectSmaBody = input.bool(true, "Reject if SMA passes through the pin bar body", group=grpRule, tooltip="If the SMA crosses the body of the setup candle, the signal is invalid.")
needDir       = input.bool(true, "SMA direction must agree (rising = buy only, falling = sell only)", group=grpRule)
slopeBars     = input.int(3, "SMA direction lookback (bars)", minval=1, group=grpRule, tooltip="SMA is 'rising' if it is above its value N bars ago, 'falling' if below.")
showPanel     = input.bool(true, "Show Persian panel", group=grpRule)
panelPos      = input.string("Top Right", "Panel position", options=["Top Left", "Top Right", "Bottom Left", "Bottom Right"], group=grpRule)

grpRng = "Range market filter (EMA)"
useRange     = input.bool(true, "Block signals in a RANGE market", group=grpRng)
rfEmaLen     = input.int(50, "EMA length", minval=2, group=grpRng)
rfSlopeBars  = input.int(10, "Slope lookback (bars)", minval=1, group=grpRng, tooltip="EMA slope = |EMA - EMA N bars ago| / ATR14")
rfSlopeMax   = input.float(0.5, "Flat if slope < (x ATR)", minval=0.01, step=0.05, group=grpRng)
rfCrossBars  = input.int(15, "Cross count window (bars)", minval=2, group=grpRng)
rfMinCross   = input.int(4, "Range if crosses >=", minval=1, group=grpRng, tooltip="Number of times the close crossed the EMA in the window.")
rfLogic      = input.string("AND", "Range condition", options=["AND", "OR"], group=grpRng, tooltip="AND: flat slope AND many crosses (strict, fewer range blocks).\nOR: flat slope OR many crosses (blocks more signals).")
showRangeBg  = input.bool(true, "Shade chart gray while RANGE", group=grpRng)
showEma      = input.bool(false, "Plot the EMA", group=grpRng)

grpVis = "Display"
showWeak  = input.bool(false, "Show pin bars rejected by SMA/size (gray dot)", tooltip="Useful while tuning the settings.")
showBoxes = input.bool(false, "Show SL / TP boxes")
rr        = input.float(4.0, "Reward : Risk (for boxes)", minval=0.1, step=0.1)
bufPips   = input.float(0.0, "SL distance from wick (pips)", minval=0, step=0.5)
boxLen    = input.int(15, "Box length (bars)", minval=3, maxval=100)
buyCol    = input.color(#26a69a, "Buy arrow color")
sellCol   = input.color(#ef5350, "Sell arrow color")

// ======================= Pin bar detection =======================
rng   = high - low
body  = math.abs(close - open)
upW   = high - math.max(open, close)
loW   = math.min(open, close) - low
atr   = ta.atr(14)
point = syminfo.mintick

bool okRange = rng > 0
bullPin = okRange and loW >= wickPct / 100.0 * rng and loW >= wickRatio * body and upW <= oppPct / 100.0 * rng
bearPin = okRange and upW >= wickPct / 100.0 * rng and upW >= wickRatio * body and loW <= oppPct / 100.0 * rng

// size filter
bool sizeOk = okRange and (minAtr == 0 or rng >= minAtr * atr) and (maxAtr == 0 or rng <= maxAtr * atr) and (minPts == 0 or rng >= minPts * point)

// SMA confirmation
sma = ta.sma(close, maLen)
bool smaBull = smaMode == "Off" or (smaMode == "Close on side" ? close > sma : (low <= sma and close > sma))
bool smaBear = smaMode == "Off" or (smaMode == "Close on side" ? close < sma : (high >= sma and close < sma))

// ---- Range market filter (uses only current/past bars, no repaint on closed candles) ----
rfEma     = ta.ema(close, rfEmaLen)
rfSlope   = math.abs(rfEma - rfEma[rfSlopeBars]) / atr
int rfCrossNow = ta.cross(close, rfEma) ? 1 : 0
rfCrosses = math.sum(rfCrossNow, rfCrossBars)
bool rfFlat   = rfSlope < rfSlopeMax
bool rfChoppy = rfCrosses >= rfMinCross
bool isRange  = useRange and (rfLogic == "AND" ? (rfFlat and rfChoppy) : (rfFlat or rfChoppy))
bool rangeOk  = not isRange

bgcolor(showRangeBg and isRange ? color.new(color.gray, 85) : na, title="Range zone")
plot(showEma ? rfEma : na, "EMA (range filter)", color=color.new(color.aqua, 0), linewidth=1)

// Rule 1: SMA must not pass through the body of the setup candle
float bodyTop = math.max(open, close)
float bodyBot = math.min(open, close)
bool smaInBody = sma >= bodyBot and sma <= bodyTop
bool bodyOk = not (rejectSmaBody and smaInBody)

// Rule 2: SMA direction must agree with the signal
bool smaUp   = sma > sma[slopeBars]
bool smaDown = sma < sma[slopeBars]
bool dirBuyOk  = not needDir or smaUp
bool dirSellOk = not needDir or smaDown

bool buySig  = bullPin and sizeOk and smaBull and bodyOk and dirBuyOk and rangeOk and barstate.isconfirmed
bool sellSig = bearPin and sizeOk and smaBear and bodyOk and dirSellOk and rangeOk and barstate.isconfirmed

var int lastSigDir = 0
var int lastSigBar = na
if buySig
    lastSigDir := 1
    lastSigBar := bar_index
if sellSig
    lastSigDir := -1
    lastSigBar := bar_index

// ======================= Plots =======================
plotshape(sellSig, "Sell pin bar", style=shape.arrowdown, location=location.abovebar, color=sellCol, size=size.normal)
plotshape(buySig,  "Buy pin bar",  style=shape.arrowup,   location=location.belowbar, color=buyCol,  size=size.normal)
plotshape(showWeak and bearPin and not sellSig and barstate.isconfirmed, "Rejected bear pin", style=shape.circle, location=location.abovebar, color=color.new(color.gray, 20), size=size.tiny)
plotshape(showWeak and bullPin and not buySig  and barstate.isconfirmed, "Rejected bull pin", style=shape.circle, location=location.belowbar, color=color.new(color.gray, 20), size=size.tiny)
plot(showMA ? sma : na, "SMA", color=color.yellow, linewidth=1)

// ======================= Optional SL / TP boxes =======================
buf = bufPips * 10.0 * point

if showBoxes and sellSig
    float sl = high + buf
    float d = sl - close
    if d > 0
        float tp = close - d * rr
        box.new(bar_index, sl, bar_index + boxLen, close, bgcolor=color.new(color.red, 85), border_color=na)
        box.new(bar_index, close, bar_index + boxLen, tp, bgcolor=color.new(color.lime, 85), border_color=na)

if showBoxes and buySig
    float sl = low - buf
    float d = close - sl
    if d > 0
        float tp = close + d * rr
        box.new(bar_index, close, bar_index + boxLen, sl, bgcolor=color.new(color.red, 85), border_color=na)
        box.new(bar_index, tp, bar_index + boxLen, close, bgcolor=color.new(color.lime, 85), border_color=na)

// ======================= Alerts =======================
alertcondition(buySig,  "Buy pin bar",  "Bullish pin bar confirmed")
alertcondition(sellSig, "Sell pin bar", "Bearish pin bar confirmed")

// ======================= Persian panel =======================
var table pnl = table.new(position.top_right, 2, 9, border_width=1)
if showPanel and barstate.islast
    table.delete(pnl)
    tpos = panelPos == "Top Left" ? position.top_left : panelPos == "Top Right" ? position.top_right : panelPos == "Bottom Left" ? position.bottom_left : position.bottom_right
    pnl := table.new(tpos, 2, 9, border_width=1, frame_color=color.new(color.gray, 40), frame_width=1)
    color bg = color.new(#1c1c26, 0)
    color lblCol = color.silver

    string dirTxt = smaUp ? "صعودی ▲" : smaDown ? "نزولی ▼" : "خنثی ■"
    color dirCol = smaUp ? color.lime : smaDown ? color.red : color.gray
    string allowTxt = smaUp ? "فقط خرید" : smaDown ? "فقط فروش" : "منتظر جهت"
    color allowCol = smaUp ? color.lime : smaDown ? color.red : color.orange
    string pinTxt = bullPin ? "صعودی (سایه پایین)" : bearPin ? "نزولی (سایه بالا)" : "ندارد"
    color pinCol = bullPin ? color.lime : bearPin ? color.red : color.gray
    string bodyTxt = smaInBody ? "بله ✗ (نامعتبر)" : "خیر ✓"
    color bodyCol = smaInBody ? color.orange : color.lime
    string sizeTxt = na(atr) or atr == 0 ? "-" : str.tostring(rng / atr, "#.##") + " × ATR " + (sizeOk ? "✓" : "✗")
    color sizeCol = sizeOk ? color.lime : color.orange
    string sigTxt = lastSigDir == 0 ? "ندارد" : (lastSigDir == 1 ? "خرید" : "فروش") + " (" + str.tostring(bar_index - lastSigBar) + " کندل پیش)"
    color sigCol = lastSigDir == 1 ? color.lime : lastSigDir == -1 ? color.red : color.gray

    table.cell(pnl, 0, 0, "پین‌بار + SMA   " + syminfo.ticker + " " + timeframe.period, text_color=color.gold, bgcolor=color.new(#2c2c3e, 0), text_size=size.small)
    table.merge_cells(pnl, 0, 0, 1, 0)
    table.cell(pnl, 0, 1, "جهت SMA", text_color=lblCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 1, 1, dirTxt, text_color=dirCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 0, 2, "جهت مجاز", text_color=lblCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 1, 2, allowTxt, text_color=allowCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 0, 3, "پین‌بار این کندل", text_color=lblCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 1, 3, pinTxt, text_color=pinCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 0, 4, "SMA از بدنه رد شده؟", text_color=lblCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 1, 4, bodyTxt, text_color=bodyCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 0, 5, "اندازه کندل", text_color=lblCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 1, 5, sizeTxt, text_color=sizeCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 0, 6, "آخرین سیگنال", text_color=lblCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 1, 6, sigTxt, text_color=sigCol, bgcolor=bg, text_size=size.small)

    string mktTxt = not useRange ? "فیلتر خاموش" : isRange ? "رنج ⛔ (سیگنال ممنوع)" : "روند ✓"
    color mktCol = not useRange ? color.gray : isRange ? color.orange : color.lime
    string rngTxt = na(rfSlope) ? "-" : str.tostring(rfSlope, "#.##") + " ATR | کراس " + str.tostring(rfCrosses, "#")
    table.cell(pnl, 0, 7, "وضعیت بازار", text_color=lblCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 1, 7, mktTxt, text_color=mktCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 0, 8, "شیب EMA / کراس‌ها", text_color=lblCol, bgcolor=bg, text_size=size.small)
    table.cell(pnl, 1, 8, rngTxt, text_color=color.white, bgcolor=bg, text_size=size.small)
