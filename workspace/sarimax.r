# 高機能な時系列データの型を提供するパッケージ
require(xts)
# 時系列モデルの作成と予測のためのパッケージ
require(forecast)
# 時系列分析のための様々な関数を提供しているパッケージ
require(tseries)
# 美麗なグラフを描くことができるパッケージ
require(ggplot2)
require(ggfortify)

# 前席の死傷者数，ガソリン価格の変動，法律の施行の有無
Seatbelts_log <- Seatbelts[,c("front","PetrolPrice","law")]
# 前席の死傷者数(時系列データ)を対数系列にする
Seatbelts_log[,"front"] <- log(Seatbelts[,"front"])
# ガソリンの価格変動も対数系列にする
Seatbelts_log[,"PetrolPrice"] <- log(Seatbelts[,"PetrolPrice"])

# 時系列データのプロット
autoplot(
  Seatbelts_log[,"front"],
  main = "Road traffic casualties in the UK (front seat)",
  xlab = "year",
  ylab = "number of casualties"
)

# 学習データとテストデータに分ける
train <- window(Seatbelts_log, end=c(1983,12))
test <- window(Seatbelts_log, start=c(1984,1))

petro_law <- train[,c("PetrolPrice","law")]
petro_law_test <- data.frame(
  PetrolPrice = rep(mean(train[, "PetrolPrice"]),12),
  law = rep(1,12)
)
petro_law_test <- ts(petro_law_test, start=c(1984,1), freq=12)

# 適当にモデルを構築してみる
model_sarimax <- Arima(
  y = train[,"front"],
  order = c(1,1,1),
  seasonal = list(order = c(1,0,0)),
  xreg = petro_law)

# 自動モデル選択(sarimax)を利用してみる
sarimax_petro_law <- auto.arima(
  y = train[, "front"], # 学習データ
  xreg = petro_law,     # 説明変数(ガソリン価格，法律の施行)の指定
  ic = "aic",           # モデル選択に使う手法
  max.order = 7,        # p+q+P+Qの最大値
  stepwise = F,         # Fは計算量をケチらないという意味
  approximation = F,    # Fは計算量をケチらないという意味
  parallel = T,         # Tは並列化演算を行うという意味
  num.cores = 4,        # 4コアで並列処理を行うという意味
)

# 定常性・反転可能性のチェック
# これらはauto.arima()の中で行われているが
# 今回は勉強のためにあえて確認する
abs(polyroot(c(1,-coef(sarimax_petro_law)[c("ar1","ar2")])))
abs(polyroot(c(1,coef(sarimax_petro_law)[c("ma1")])))
abs(polyroot(c(1,-coef(sarimax_petro_law)[c("sma1")])))

# 残差の自己相関の検定(帰無仮説は"自己相関はない")
# 残差にホワイトノイズを仮定しているので，
# 自己相関はないと判断されるはず
checkresiduals(sarimax_petro_law)

# 残差の正規性の検定(帰無仮説は"正規分布と有意に異なっているとは言えない")
# ホワイトノイズなので(0,σ^2)に従っているか確認する
jarque.bera.test(resid(sarimax_petro_law))

# 構築したsarimaxによる予測を行う
sarimax_f <- forecast(
  sarimax_petro_law,     # モデルの指定
  xreg = petro_law_test, # 説明変数の追加
  h = 12,                # 12時点先まで予測
  level = c(95,70)       # 95%,70%予測区間も併せて出力
)

# 予測結果のプロット
autoplot(
  sarimax_f,
  predict.colour = 2,
  main = "forecast by SARIMAX"
)

# テストデータを用いた予測の評価
# 評価指標として，RMSEを採用する(小さい方が良い)
accuracy(sarimax_f, x=test[, "front"])

# ナイーブ予測による比較
naive_f_mean <- meanf(train[, "front"], h = 12)
accuracy(naive_f_mean, x=test[, "front"])

naive_f_latest <- rwf(train[, "front"], h = 12)
accuracy(naive_f_latest, x=test[, "front"])
