using OceanTurb

@use_pyplot_utils # add utilities for plotting OceanTurb Fields

     N = 128        # Model resolution
     L = 128        # Vertical extent of the model domain
    Qᵘ = 1e-4       # Surface buoyancy flux (positive implies cooling)
  dTdz = 1e-3       # Interior/initial temperature gradient
    Δt = 10minute   # Time step size
tfinal = 8hour      # Final time

# Build the model with a Backward Euler timestepper
model = TKEMassFlux.Model(N=N, L=L, stepper=:BackwardEuler)

# Set initial condition
T₀(z) = 20 + dTdz * z
model.solution.T = T₀

# Set boundary conditions
model.bcs.U.top = FluxBoundaryCondition(Qᵘ)
model.bcs.T.bottom = GradientBoundaryCondition(dTdz)

# Run the model
run_until!(model, Δt, tfinal)

plot(model.solution.T)
removespines("top", "right")
xlabel("Temperature (\$ {}^\\circ \\mathrm{C} \$)")
ylabel(L"z \, \mathrm{(m)}")

#gcf()
#savefig("figs/kpp_free_convection.png", dpi=480)
