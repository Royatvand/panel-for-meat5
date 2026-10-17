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

bool buySig  = bullPin and sizeOk and smaBull and barstate.isconfirmed
bool sellSig = bearPin and sizeOk and smaBear and barstate.isconfirmed

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
