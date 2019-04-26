using Logging
ENV["JULIA_DEBUG"] = "all"
logger = ConsoleLogger(stdout, Logging.Debug);

using BenchmarkTools
import Random.seed!
seed!(0)

include("../src/common.jl")
include("../src/SpatialPooler.jl")

#display(@benchmark sp= SpatialPoolerM.SpatialPooler())
inputDims= (24,24)
spDims= (32,32)
sp= SpatialPoolerM.SpatialPooler(SpatialPoolerM.SPParams(
      inputDims,spDims,
      input_potentialRadius=5,
      T_boost=800,
      θ_stimulus_act=1,
      enable_boosting=true))

activity= falses(prod(inputDims))
activity[rand(1:prod(inputDims),prod(inputDims)÷2)].= true
SpatialPoolerM.step!(sp,activity)
sp_activity= SpatialPoolerM.sp_activation(sp.proximalSynapses,sp.φ.φ,sp.b,activity', sp.params.spSize,sp.params)

# Show synapse adaptation!
using Plots
for t= 1:2500
  activity= falses(prod(inputDims))
  activity[rand(1:prod(inputDims),prod(inputDims)÷2)].= true
  sp_activity= SpatialPoolerM.step!(sp,activity)

  t%100==0 && begin
    println("t=$t")
    sparsity= count(sp_activity)/prod(spDims)*100
    sparsity|> display

    #histogram(sp.b.a_Tmean-sp.b.a_Nmean|>vec)|> display
    #histogram(sp.b.b)|> display
    #histogram(sp.proximalSynapses.synapses[sp.proximalSynapses.synapses.>0])|> display
    #heatmap(sp.b.a_Tmean)|> display
    #heatmap(sp.proximalSynapses.synapses)|> display
  end
end
highConn= @> sp.proximalSynapses.synapses.data sum(dims=1) vec sortperm(rev=true)
( count(sp.proximalSynapses.synapses.>0)/length(sp.proximalSynapses.synapses) )|> display
