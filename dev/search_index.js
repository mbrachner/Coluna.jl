var documenterSearchIndex = {"docs":
[{"location":"start/#Quick-start-1","page":"Quick start","title":"Quick start","text":"","category":"section"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"This quick start guide introduces main features of Coluna.jl package through an example.","category":"page"},{"location":"start/#Start-1","page":"Quick start","title":"Start","text":"","category":"section"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"using JuMP, BlockDecomposition, GLPK, Coluna","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"We instantiate the solver and define how we want to solve the decomposed formulation.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"coluna = JuMP.optimizer_with_attributes(\n    Coluna.Optimizer,\n    \"params\" => Coluna.Params(\n        global_strategy = Coluna.GlobalStrategy(\n                Coluna.SimpleBnP(), Coluna.SimpleBranching(), Coluna.DepthFirst())\n        ),\n    \"default_optimizer\" => with_optimizer(GLPK.Optimizer)\n)","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"Then, we instanciate the model","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"model = BlockModel(coluna, bridge_constraints = false)","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"The second argument is mandatory because of a bug in MOI/BlockDecomposition.","category":"page"},{"location":"start/#Generalized-Assignment-Problem-1","page":"Quick start","title":"Generalized Assignment Problem","text":"","category":"section"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"Assume we want to solve the following instance :","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"M = 4\nJ = 30\nCost = [12.7 22.5 8.9 20.8 13.6 12.4 24.8 19.1 11.5 17.4 24.7 6.8 21.7 14.3 10.5 15.2 14.3 12.6 9.2 20.8 11.7 17.3 9.2 20.3 11.4 6.2 13.8 10.0 20.9 20.6;  19.1 24.8 24.4 23.6 16.1 20.6 15.0 9.5 7.9 11.3 22.6 8.0 21.5 14.7 23.2 19.7 19.5 7.2 6.4 23.2 8.1 13.6 24.6 15.6 22.3 8.8 19.1 18.4 22.9 8.0;  18.6 14.1 22.7 9.9 24.2 24.5 20.8 12.9 17.7 11.9 18.7 10.1 9.1 8.9 7.7 16.6 8.3 15.9 24.3 18.6 21.1 7.5 16.8 20.9 8.9 15.2 15.7 12.7 20.8 10.4;  13.1 16.2 16.8 16.7 9.0 16.9 17.9 12.1 17.5 22.0 19.9 14.6 18.2 19.6 24.2 12.9 11.3 7.5 6.5 11.3 7.8 13.8 20.7 16.8 23.6 19.1 16.8 19.3 12.5 11.0]\nWeight = [61 70 57 82 51 74 98 64 86 80 69 79 60 76 78 71 50 99 92 83 53 91 68 61 63 97 91 77 68 80; 50 57 61 83 81 79 63 99 82 59 83 91 59 99 91 75 66 100 69 60 87 98 78 62 90 89 67 87 65 100; 91 81 66 63 59 81 87 90 65 55 57 68 92 91 86 74 80 89 95 57 55 96 77 60 55 57 56 67 81 52;  62 79 73 60 75 66 68 99 69 60 56 100 67 68 54 66 50 56 70 56 72 62 85 70 100 57 96 69 65 50]\nCapacity = [1020 1460 1530 1190]","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"We have a set of machines Machines = 1:M and a set of jobs Jobs = 1:J. A machine m has a resource capacity Capacity[m]. When we assign a job j to a machine m, the job has a cost Cost[m,j] and consumes Weight[m,j] resource units of the machine m. The goal is to minimize the jobs cost sum by assigning each job to a machine while not exceeding the capacity of each machine.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"Let x_mj equal to one if job j is assigned to machine m; 0 otherwise.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"beginalignat4 \nGAP equiv min rlapsum_m in textMachines c_mj x_mj labelobj \ntextst  sum_m in textMachines x_mj = 1  quad j in textJobs labelmast \n sum_j in textJobs x_mj leq C_m  quad  quad m in textMachines   labelknp \n x_mj  in 01  m in textMachines j in textJobs\nendalignat","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"Since the knapsack problem is tractable, we want to apply a Dantzig-Wolfe  decomposition to the model GAP to get one knapsack subproblem per machine.  Let (Q^m)_m in textMachines be the set of knapsack subproblems.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"The axis is the index set of subproblems. First, we define the axis Machines.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"@axis(Machines, 1:M)\nJobs = 1:J","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"Then, we write the model","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"@variable(model, x[m in Machines, j in Jobs], Bin)\n\n@constraint(model, cov[j in Jobs],\n        sum(x[m, j] for m in Machines) >= 1)\n\n@constraint(model, knp[m in Machines],\n        sum(Weight[m, j] * x[m, j] for j in Jobs) <= Capacity[m])\n\n@objective(model, Min,\n        sum(Cost[m, j] * x[m, j] for m in Machines, j in Jobs))","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"Afterward, we apply the Dantzig-Wolfe decomposition according to axis Machines.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"@dantzig_wolfe_decomposition(model, decomposition, Machines)","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"We retrieve the master and the subproblems.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"master = getmaster(decomposition)\nsubproblems = getsubproblems(decomposition)","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"We specify that the lower multiplicity of subproblems is 0.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"specify!(subproblems, lower_multiplicity = 0, upper_multiplicity = 1)","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"Now, we can solve the problem.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"optimize!(model)","category":"page"},{"location":"start/#Logs-1","page":"Quick start","title":"Logs","text":"","category":"section"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"For every node, we print the best known primal and dual bounds.","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"************************************************************\n1 open nodes. Treating node 5. Parent is 1\nCurrent best known bounds : [ 579.0 , 580.0 ]\nElapsed time: 1.2622311115264893 seconds\nSubtree dual bound is 580.0\nBranching constraint:  + 1.0 x[3,24] >= 1.0 \n************************************************************","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"Within a node, and for each column generation iteration, we print:","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"<it=3> <et=7> <mst=0.000> <sp=0.001> <cols=4> <mlp=100570.3000> <DB=-299343.0000> <PB=Inf>\n<it=4> <et=7> <mst=0.000> <sp=0.001> <cols=4> <mlp=584.7000> <DB=9.1000> <PB=584.7000>\n<it=5> <et=7> <mst=0.000> <sp=0.001> <cols=4> <mlp=439.1000> <DB=9.1000> <PB=439.1000>","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"the iteration number it\nthe elapsed time et in seconds \nthe elapsed time solving the linear relaxation of the restricted master mst in seconds\nthe number of columns added to the restricted master cols\nthe objective value of the restricted master LP mlp\nthe computed lagrangian dual bound in this iteration DB\nthe best integer primal bound PB","category":"page"},{"location":"start/#","page":"Quick start","title":"Quick start","text":"We also use TimerOutputs.jl package to print, at the end of the resolution, the time consumed and the allocations made in most critical sections.","category":"page"},{"location":"installation/#Installation-1","page":"Installation","title":"Installation","text":"","category":"section"},{"location":"installation/#","page":"Installation","title":"Installation","text":"Coluna is a package for Julia 1.0+. ","category":"page"},{"location":"installation/#","page":"Installation","title":"Installation","text":"It requires JuMP to model the problem, BlockDecomposition to define the decomposition, and GLPK as the default underlying MOI Optimizer for the master and the subproblems.","category":"page"},{"location":"installation/#Getting-Coluna.jl-1","page":"Installation","title":"Getting Coluna.jl","text":"","category":"section"},{"location":"installation/#","page":"Installation","title":"Installation","text":"Coluna.jl can be installed using the package manager of Julia.  Go to the Pkg-REPL-mode.  The Pkg REPL-mode is entered from the Julia REPL using the key ].  Then, run the following command :","category":"page"},{"location":"installation/#","page":"Installation","title":"Installation","text":"pkg> add Coluna","category":"page"},{"location":"installation/#","page":"Installation","title":"Installation","text":"This command will install Coluna.jl and its dependencies.","category":"page"},{"location":"installation/#","page":"Installation","title":"Installation","text":"You can start using Coluna by doing :","category":"page"},{"location":"installation/#","page":"Installation","title":"Installation","text":"using Coluna","category":"page"},{"location":"#Home-1","page":"Home","title":"Home","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Coluna.jl solves Mixed Integer Programs (MIP) by applying reformulation techniques such as Dantzig-Wolfe decomposition. The reformulated problem is solved using a branch-and-price-and-cut (column and row generation) algorithm. The specificity of Coluna.jl is to offer a “black-box” implementation of the method:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"the input is the set of constraints and variables of the MIP in its natural/compact formulation (formulated with JuMP or MOI); the Block-Decompostion.jl package offers extensions to the modeling language JuMP to allow the user to provide instructions on decomposition to Coluna;\nthe user defines subsystems in the MIP on which the decomposition is based; subsystems are described by rows and/or columns indices; this is handy to test different decompositions;\nthe reformulation is automatically generated by Coluna, without any input from the user to define master columns, their reduced cost, pricing/separation problem, or Lagrangian bound;\na default column and cut generation procedure is implemented. It relies on underlying MOI optimizers to handle master and subproblem but the user can define its own optimizer;\na branching scheme that preserves the pricing problem structure is offered by default; it runs based on priorities and directives specified by the user on the original variables; default primal heuristics and preprocessing features are under developments.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The user must be familiar with the syntax of JuMP, which is described in its documentation.","category":"page"},{"location":"#Manual-Outline-1","page":"Home","title":"Manual Outline","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Pages = [\n    \"index.md\",\n    \"installation.md\",\n    \"start.md\"\n]\nDepth = 1","category":"page"}]
}
