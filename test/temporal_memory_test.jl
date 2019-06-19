using Logging
ENV["JULIA_DEBUG"] = "all"
logger = ConsoleLogger(stdout, Logging.Debug);

using BenchmarkTools
using CSV
using Printf
using StatsBase: median
using Plots; gr()
import Random: seed!, bitrand
#seed!(0)
seed!()

include("../src/common.jl")
include("../src/SpatialPooler.jl")
include("../src/encoder.jl")
include("../src/decoder.jl")
include("../src/TemporalMemory.jl")
include("utils/utils.jl")

plot_mase(data,pred,pred_timesteps)= begin
  windowLength= 240
  errormetric= zeros(length(data)-windowLength)
  for w=1:length(data)-windowLength
    errormetric[w]= mase(data[w:w+windowLength-1], pred[w:w+windowLength-1], pred_timesteps)
  end
  crit_t1= 1:500; crit_t2= 1640:2000
  plot(plot(errormetric, label="10-day MASE"),
       plot([data pred], label=["timeseries","prediction"], legend=:none),
       plot(plot(crit_t1, [data[crit_t1] pred[crit_t1]], legend= :none),
            plot(crit_t2, [data[crit_t2] pred[crit_t2]], legend= :none),
            layout= (1,2)),
       layout= (3,1))|> display
  @printf("Min 10-day MASE: %.2f\n",minimum(errormetric))
end
display_evaluation(t,sp,sp_activity,spDims)= println("t=$t")
process_data!(tN,data,encParams,sp,tm,decoder)=
  for t in 1:tN
    z,a,power_bucket= _process_sp(t,tN,data,encParams,sp,display_evaluation)
    A,Π,B= _process_tm(t,tN, tm,a)
    prediction= predict!(decoder,Π,power_bucket)
    likelyPred= reverse_simpleArithmetic(prediction,"highmean",encParams.power_p)
    history_enc[:,t]= z;    history_SP[:,t]= a
    history_TMout[:,t]= A;  history_TMpred[:,t]= Π
    history_decodedPred[:,t]= prediction; history_likelyPred[t]= likelyPred

    global avg_burst= ((t-1)*avg_burst+count(B)/length(B))/t
  end

prediction_timesteps=1
inputDims= ((15,6,3).*25,)
spDims= (1600,)
cellϵcol= 8
sp= SpatialPooler(SPParams(
      szᵢₙ= map(sum,inputDims), szₛₚ=spDims,
      γ=1000,
      s=0.03,
      θ_potential_prob=0.85,
      θ_stimulus_activate=5,
      p⁺_01= 0.20,
      p⁻_01= 0.12,
      β=3,
      Tboost=350,
      enable_local_inhibit=false,
      enable_boosting=true))
tm= TemporalMemory(TMParams(
      Nc=prod(spDims),
      cellϵcol=cellϵcol,
      θ_stimulus_activate=14,
      θ_stimulus_learn=12,
      synapseSampleSize=35,
      p⁺_01=0.24,
      p⁻_01=0.08,
      LTD_p⁻_01= 0.012
     ))

Ncol= prod(spDims); Ncell= Ncol*cellϵcol
# Define input data
data,tN= read_gympower()
encParams= initenc_powerDay(data.power_hourly_kw, data.hour, data.is_weekend,
                 encoder_size=inputDims[1], w=(34,35,35))
decoder= SDRClassifier(Ncell,encParams.power_p.buckets,
                  α=0.09, buffer_length=prediction_timesteps)
# Histories
history_enc= falses(map(sum,inputDims)|>prod,tN)
history_SP= falses(Ncol,tN)
history_TMout=  falses(Ncell,tN)
history_TMpred= falses(Ncell,tN)
history_decodedPred= zeros(encParams.power_p.buckets,tN)
history_likelyPred= zeros(tN)
avg_burst= 0

process_data!(tN,data,encParams,sp,tm,decoder)

errormetric= mase(data.power_hourly_kw[400:end], history_likelyPred[400:end],prediction_timesteps)
@printf("Prediction MASE: %.3f\n", errormetric)

avg_TMout_sparsity= mapslices(x->count(x)./length(x),history_TMout,dims=1)'|>median
plot_mase(data.power_hourly_kw, history_likelyPred, prediction_timesteps)
@printf("avg_TMout_sparsity: %.3f%%\n", 100*avg_TMout_sparsity)
@printf("avg_burst: %.3f%%\n", 100*avg_burst)
