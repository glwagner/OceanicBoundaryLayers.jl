module TKEMassFlux

using OceanTurb
using OceanTurb: nan2inf, inf2zero

using Printf

import ..OceanTurb: oncell, onface
import .KPP: ∂B∂z, u★, isunstable
import .ModularKPP: AbstractModularKPPModel

const nsol = 5
@solution U V T S e

@inline minuszero(args...) = -0

@inline maxsqrt(ϕ::T) where T = sqrt(max(zero(T), ϕ))
@inline maxsqrt(ϕ, i) = @inbounds maxsqrt(ϕ[i])

"Returns √ϕ if ϕ is positive and not NaN. Otherwise returns 0."
@inline function zeroed_sqrt(ϕ)
    ϕ *= 1 - isnan(ϕ)
    return maxsqrt(ϕ)
end

@inline zeroed_sqrt(ϕ, i) = @inbounds zeroed_sqrt(ϕ[i])

@inline sqrt_e(m, i) = @inbounds maxsqrt(m.solution.e[i])

@inline ∂B∂z(m, i) = ∂B∂z(m.solution.T, m.solution.S, 
                          m.constants.g, m.constants.α, m.constants.β, i)

@inline oncell_∂B∂z(m, i) = oncell(∂B∂z, m, i) # Fallback valid for linear equations of state

@inline sqrt_∂B∂z(m, i) = maxsqrt(∂B∂z(m, i))

mutable struct Model{L, K, W, E, H, P, K0, C, ST, G, TS, S, BC, T} <: AbstractModel{TS, G, T}
                       clock :: Clock{T}
                        grid :: G
                 timestepper :: TS
                    solution :: S
                         bcs :: BC
               mixing_length :: L
          eddy_diffusivities :: K
              tke_wall_model :: W
                tke_equation :: E
        boundary_layer_depth :: H
               nonlocal_flux :: P
    background_diffusivities :: K0
                   constants :: C
                       state :: ST
end

include("state.jl")
include("mixing_length.jl")
include("tke_equation.jl")
include("wall_models.jl")
include("diffusivities.jl")

function Model(; 
                      grid = UniformGrid(N, L),
                 constants = Constants(),
             mixing_length = EquilibriumMixingLength(),
        eddy_diffusivities = SinglePrandtlDiffusivities(),
            tke_wall_model = PrescribedSurfaceTKEFlux(),
              tke_equation = TKEParameters(),
      boundary_layer_depth = nothing,
             nonlocal_flux = nothing,
  background_diffusivities = BackgroundDiffusivities(),
                   stepper = :BackwardEuler,
)

    solution = Solution((CellField(grid) for i=1:nsol)...)

    tke_bcs = TKEBoundaryConditions(eltype(grid), tke_wall_model)

    bcs = (
        U = DefaultBoundaryConditions(eltype(grid)),
        V = DefaultBoundaryConditions(eltype(grid)),
        T = DefaultBoundaryConditions(eltype(grid)),
        S = DefaultBoundaryConditions(eltype(grid)),
        e = tke_bcs
    )

    Kϕ = (U=KU, V=KV, T=KT, S=KS, e=Ke)
    Rϕ = (U=RU, V=RV, T=RT, S=RS, e=Re)
    Lϕ = (U=minuszero, V=minuszero, T=minuszero, S=minuszero, e=Le)
    eq = Equation(K=Kϕ, R=Rϕ, L=Lϕ, update=update_state!)
    lhs = OceanTurb.build_lhs(solution)

    timestepper = Timestepper(stepper, eq, solution, lhs)

    return Model(Clock(), 
                 grid, 
                 timestepper, 
                 solution, 
                 bcs, 
                 mixing_length, 
                 eddy_diffusivities,
                 tke_wall_model, 
                 tke_equation, 
                 boundary_layer_depth,
                 nonlocal_flux, 
                 background_diffusivities,
                 constants, 
                 State(grid, mixing_length, boundary_layer_depth)
                )
end


@inline RU(m, i) = @inbounds   m.constants.f * m.solution.V[i]
@inline RV(m, i) = @inbounds - m.constants.f * m.solution.U[i]
@inline RT(m, i) = 0
@inline RS(m, i) = 0

@inline Re(m, i) = production(m, i) + buoyancy_flux(m, i) - dissipation(m, i)
@inline Le(m, i) = 0

end # module
