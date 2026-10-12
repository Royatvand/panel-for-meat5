# panel-for-meat5


> Note: file extensions must be `.mq5` for MetaTrader 5.  
> (`.mq4` is for MetaTrader 4)

---

## ⚙️ Installation

1. Open **MetaTrader 5**
2. Go to **File → Open Data Folder**
3. Navigate to `MQL5/Experts/`
4. Copy the `.mq5` files into that folder
5. In MetaTrader, press **F4** to open MetaEditor
6. Open the file and click **Compile** (F7)
7. Back in MT5, drag the EA onto a chart
8. Enable **AutoTrading** and allow algorithmic trading in EA settings

---

## 🚀 Usage

| Input            | Description                                  | Default |
|------------------|----------------------------------------------|---------|
| `RiskPercent`    | Risk per trade (% of balance)                | `1.0`   |
| `MaxLot`         | Maximum allowed lot size                     | `5.0`   |
| `SL_Pips`        | Stop Loss in pips                            | `30`    |
| `TP_Pips`        | Take Profit in pips                          | `60`    |
| `UseBreakEven`   | Enable break-even logic                      | `true`  |
| `TrailStop`      | Trailing stop distance (pips)                | `20`    |
| `MaxPositions`   | Max simultaneously open positions            | `3`     |
| `DailyLossLimit` | Daily loss limit (%)                         | `5.0`   |
| `SessionStart`   | Trading session start (server time)          | `08:00` |
| `SessionEnd`     | Trading session end (server time)            | `20:00` |

---

## 🧠 How It Works

1. Calculates lot size from **account balance × risk % ÷ SL distance**
2. Validates against **max lot** and **margin requirements**
3. Places order with **SL/TP** already attached
4. Monitors position for **break-even** and **trailing**
5. Blocks new trades if **daily loss limit** or **max positions** is reached
6. Logs every action for review

---

## ⚠️ Disclaimer

Trading involves risk. This EA is provided **as-is** for educational purposes.  
Always test on a **demo account** first, then on a **cent account**, before using real money.  
Past performance does not guarantee future results.

---

## 🗺️ Roadmap

- [x] v1 — simple base EA
- [x] v2 — improved UI
- [x] v3 — full money management panel
- [ ] v4 — multi-symbol support
- [ ] v5 — Telegram notifications
- [ ] v6 — backtest optimization presets

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first.

---

## 📜 License

MIT License — free to use, modify, and distribute.

---

## 👤 Author

**pytho584**  
GitHub: [@pytho584](https://github.com/pytho584)

---

# 🇮🇷 نسخه فارسی

## پنل مدیریت سرمایه برای متاتریدر ۵

یک **اکسپرت مدیریت سرمایه** سبک و مطمئن برای **MetaTrader 5** که با زبان MQL5 نوشته شده است.  
هدف این اکسپرت، **محاسبه حجم معامله بر اساس ریسک، کنترل ضرر و محافظت از سرمایه** است — ساده برای استفاده، امن برای اجرا.

## ✨ امکانات

- 📊 محاسبه حجم لات بر اساس موجودی و درصد ریسک
- 🛡️ محافظت در برابر افت سرمایه (Drawdown)
- 📈 تنظیم خودکار حد ضرر و حد سود
- 🔁 انتقال به نقطه سربهسر و تریلینگ استاپ
- ⚖️ محدودیت تعداد پوزیشن و حداکثر لات
- 🕐 فیلتر ساعات معاملاتی
- 📰 فیلتر اخبار (اختیاری)
- 🧾 لاگ و هشدار کامل برای هر تصمیم

## ⚙️ نصب

1. متاتریدر ۵ رو باز کن
2. **File → Open Data Folder**
3. برو به `MQL5/Experts/`
4. فایلهای `.mq5` رو اونجا کپی کن
5. توی متاتریدر **F4** بزن تا MetaEditor باز شه
6. فایل رو باز کن و **F7** بزن (Compile)
7. برگرد توی MT5 و اکسپرت رو روی چارت بکش
8. **AutoTrading** رو روشن کن

## ⚠️ هشدار

معامله در بازارهای مالی ریسک دارد. این اکسپرت **همانطور که هست** برای اهداف آموزشی ارائه شده.  
اول روی **حساب دمو**، بعد روی **حساب سنت**، و در آخر با پول واقعی تست کن.  
عملکرد گذشته تضمینی برای آینده نیست.

## 📜 مجوز

MIT — آزاد برای استفاده، تغییر و توزیع.

---

⭐ If this project helped you, give it a star!
