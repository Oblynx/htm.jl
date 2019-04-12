module SpatialPoolerM

include("common.jl")
include("topology.jl")
include("dynamical_systems.jl")

# NOTE: Instead of making type aliases, perhaps parametrize IntSP etc?
struct SPParams{Nin,Nsp}
  inputSize::NTuple{Nin,UIntSP}
  spSize::NTuple{Nsp,UIntSP}
  input_potentialRadius::UIntSP
  sparsity::FloatSP
  θ_potential_prob_prox::FloatSP
  θ_permanence_prox::FloatSP
  θ_stimulus_act::UIntSP
  n_active_perinhibit::UIntSP
  enable_local_inhibit::Bool
  enable_learning::Bool
  topologyWraps::Bool
end

# SPParams convenience constructor and default arguments.
#   Obligatory validity checks should be an inner constructor
function SPParams(inputSize::NTuple{Nin,UIntSP}= UIntSP.((32,32)),
                  spSize::NTuple{Nsp,UIntSP}= UIntSP.((64,64));
                  input_potentialRadius=16,
                  sparsity=0.2,
                  θ_potential_prob_prox=0.5,
                  θ_permanence_prox=0.4,
                  θ_stimulus_act=0,
                  n_active_perinhibit=10,
                  enable_local_inhibit=true,
                  enable_learning=true,
                  topologyWraps=false
                 ) where {Nin,Nsp}
  # Param transformation
  # cover the entire input space, reasonable if no topology
  if input_potentialRadius == 0
    input_potentialRadius= max(inputSize)
  end

  ## Construction
  SPParams{Nin,Nsp}(inputSize,spSize,input_potentialRadius,sparsity,
           θ_potential_prob_prox,θ_permanence_prox,θ_stimulus_act,
           n_active_perinhibit,
           enable_local_inhibit,enable_learning,topologyWraps)
end

struct SpatialPooler{Nin,Nsp} #<: Region
  params::SPParams
  proximalSynapses::ProximalSynapses
  φ::InhibitionRadius

  # Nin, Nsp: number of input and spatial pooler dimensions
  function SpatialPooler(params::SPParams{Nin,Nsp}= SPParams()) where {Nin,Nsp}
    new{Nin,Nsp}(params,
        ProximalSynapses(params.inputSize,params.spSize,
            params.input_potentialRadius,params.θ_potential_prob_prox,
            params.θ_permanence_prox),
        InhibitionRadius(params.input_potentialRadius)
    )
  end
end


"""
      step!(z::CellActivity, sp::SpatialPooler)

  Evolve the Spatial Pooler to the next timestep.

  ...
  # Input
    - `z`: array of active input cells, arranged in a metric space.
    - `params`: structure of miscellaneous SP hyperparameters
      - `input_potentialRadius`
      - `sparsity`
      - `θ_potential_prob_prox`
      - `θ_permanence_prox`
      - `θ_stim_act`
      - `enable_local_inhibit`
      - `enable_learning`
  ## Modified
    - proximalSynapses: as a result of the learning process, the proximalSynapses are
        modified at each step. Maps from input array to array of minicolumns.
        proximalSynapses[x_i,y_i]:= permanence value, where x_i,y_i are tuples
  # Output
    - minicolAct: array of minicolumn activation. Minicolumns are embedded in a metric space,
        and the array dimensionality represents the spatial dimensions (normally 2 - affects
        local inhibition)
  ...

  # Notes

  ## Definitions
    - `xᵢ`: position of input cell `i`
    - `yᵢ`: position of minicolumn `i`
    - `γ`: side of hypercube of potential connections in input space
    - `φ`: radius of local inhibition sphere in minicolumn space

  ## Mapping input to minicolumns

  There is an implied spatial mapping between the input and output spaces. Minicolumn `i` has
  potential synapses only with some input cells close to input `i` ("close": hypercube around
  cell `i`) (param: `input_potentialRadius`).
  For every input in that area, there is a uniformly-distributed probability that
  it connects to the minicolumn (param: `θ_potential_prob_prox`).
  Permanence values for potential synapses are also uniformly iid, with connection threshold
  0.5 (param: `θ_permanence_prox`). Performance NOT SENSITIVE to this.

  ## Local inhibition

  Local inhibition happens in the neighborhood of minicolumn `i`: euclidean hypersphere
  around `y_i` of radius `φ`. The radius is dynamically adjusted. Its initial value is
  determined by the ratio `R` of the size of the output to input space -- it is assumed that
  the mapping between the input and output space is an isotropic scaling; eg, the spaces are
  rectangular with the same aspect ratio.

      ``φ_0 = Rγ``

  Of course this can be generalized to the case of a non-isotropic scaling between the 2
  spaces, by letting `R` be the transformation matrix. If the dimensions of the 2 spaces
  are not the same, however, there will be extra degrees of freedom.

  Local inhibition makes sense only if the input space has topology, and can be turned off
  (param: `enable_local_inhibit`).

  ## SP activation

  The final activation of each minicolumn is a result of its (boosted) "overlap" `o` with the
  input. There is a threshold (param: `θ_stimulus_act`), which the overlap must pass. Then, local
  inhibition allows only the top `s`% of the neighborhood to become active
  (param: `sparsity` ≈ 2%).

  ## Learning

  (param: `enable_learning`)

"""
function step!(z::CellActivity, sp::SpatialPooler)
  W()= sp.proximalSynapses .> sp.params.θ_permanence_prox
  N(y,φ)= (j for j in hypersphere(y,φ,sp.spSize) if j!=y)
  #φ(W)=
end

end
