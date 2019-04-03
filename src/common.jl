using SparseArrays
using StaticArrays
using Setfield

# Type aliases
const IntSP= Int32
const UIntSP= UInt32
const FloatSP= Float32
const SynapsePermanenceQuantization= Int8
const Option{T}= Union{T,Nothing}
const Maybe{T}= Union{T,Missing}

export IntSP, UIntSP, FloatSP, SynapsePermanenceQuantization

include("synapses.jl")

const CellActivity= BitArray

# Synapses don't belong to regions!
struct Region
end
