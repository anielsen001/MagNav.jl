using MagNav, Test, MAT, DataFrames, Flux, Statistics, Zygote

flight   = :Flt1003
xyz_type = :XYZ20
map_name = :Eastern_395
xyz_h5   = string(MagNav.sgl_2020_train(),"/$(flight)_train.h5")
mapE_h5  = string(MagNav.ottawa_area_maps(),"/$(map_name).h5")
xyz      = get_XYZ20(xyz_h5;tt_sort=true,silent=true)
mapS     = get_map(mapE_h5)

line_train = unique(xyz.line)[2]
line_test  = unique(xyz.line)[3]
ind_train  = xyz.line .== line_train
ind_test   = xyz.line .== line_test
ind_train[findall(ind_train)[51:end]] .= false
ind_test[ findall(ind_test )[51:end]] .= false
mapS   = map_trim(mapS,xyz.traj(ind_train .| ind_test))
map_h5 = joinpath(@__DIR__,"test_compensation.h5")
save_map(mapS,map_h5)

t_start = [xyz.traj.tt[ind_train][1],xyz.traj.tt[ind_test][1]]
t_end   = [xyz.traj.tt[ind_train][end],xyz.traj.tt[ind_test][end]]

df_line = DataFrame(flight   = [flight,flight],
                    line     = [line_train,line_test],
                    t_start  = t_start,
                    t_end    = t_end,
                    map_name = [map_name,map_name])

df_flight = DataFrame(flight   = flight,
                      xyz_type = xyz_type,
                      xyz_set  = 1,
                      xyz_h5   = xyz_h5)

df_map = DataFrame(map_name = map_name,
                   map_h5   = map_h5)

terms     = [:p]
terms_A   = [:p,:i,:e]
batchsize = 5

comp_params_1  = MagNav.NNCompParams(model_type=:m1 ,terms=terms,
                                     terms_A=terms_A,batchsize=batchsize)
comp_params_2a = MagNav.NNCompParams(model_type=:m2a,terms=terms,
                                     terms_A=terms_A,batchsize=batchsize)
comp_params_2b = MagNav.NNCompParams(model_type=:m2b,terms=terms,
                                     terms_A=terms_A,batchsize=batchsize)
comp_params_2c = MagNav.NNCompParams(model_type=:m2c,terms=terms,
                                     terms_A=terms_A,batchsize=batchsize)
comp_params_2d = MagNav.NNCompParams(model_type=:m2d,terms=terms,
                                     terms_A=terms_A,batchsize=batchsize)

comp_params_nn_bad      = MagNav.NNCompParams( model_type=:test)
comp_params_lin_bad     = MagNav.LinCompParams(model_type=:test)
drop_fi_bson = joinpath(@__DIR__,"drop_fi")
drop_fi_csv  = joinpath(@__DIR__,"drop_fi.csv")
comp_params_nn_bad_drop = MagNav.NNCompParams(model_type=:test,drop_fi=true, 
                                              drop_fi_bson=drop_fi_bson,
                                              drop_fi_csv=drop_fi_csv)

x = [1:5;;]
y = [1:5;]

@testset "comp_train tests" begin
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_1 )[end-1]) < 1
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_2a)[end-1]) < 1
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_2b)[end-1]) < 1
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_2c)[end-1]) < 1
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_2d)[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_1 )[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_2a)[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_2b)[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_2c)[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_2d)[end-1]) < 1
    @test isone(plsr_fit(x,y;return_set=true)[:,:,1])
    @test std(elasticnet_fit(x,y;λ=0.01)[end]) < 1
    @test_throws ErrorException comp_train(xyz,ind_train;
                                           comp_params=comp_params_nn_bad)
    @test_throws ErrorException comp_train(xyz,ind_train;
                                           comp_params=comp_params_lin_bad)
    @test_throws ErrorException comp_train(xyz,ind_train;
                                           comp_params=comp_params_nn_bad_drop)
    @test_throws ErrorException comp_train(line_train,df_line,df_flight,DataFrame(),
                                           comp_params_nn_bad)
    @test_throws ErrorException comp_train(line_train,df_line,df_flight,DataFrame(),
                                           comp_params_lin_bad)
    @test_throws ErrorException comp_train(line_train,df_line,df_flight,DataFrame(),
                                           comp_params_nn_bad_drop)
end

comp_params_1  = comp_train(xyz,ind_train;comp_params=comp_params_1 )[1]
comp_params_2a = comp_train(xyz,ind_train;comp_params=comp_params_2a)[1]
comp_params_2b = comp_train(xyz,ind_train;comp_params=comp_params_2b)[1]
comp_params_2c = comp_train(xyz,ind_train;comp_params=comp_params_2c)[1]
comp_params_2d = comp_train(xyz,ind_train;comp_params=comp_params_2d)[1]

drop_fi_bson = joinpath(@__DIR__,"drop_fi")
comp_train(xyz,ind_train;comp_params=MagNav.NNCompParams(comp_params_1,
           drop_fi=true,drop_fi_bson=drop_fi_bson,drop_fi_csv=drop_fi_csv))

@testset "comp_train (re-train) tests" begin
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_1 )[end-1]) < 1
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_2a)[end-1]) < 1
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_2b)[end-1]) < 1
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_2c)[end-1]) < 1
    @test std(comp_train(xyz,ind_train;comp_params=comp_params_2d)[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_1 )[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_2a)[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_2b)[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_2c)[end-1]) < 1
    @test std(comp_train(line_train,df_line,df_flight,DataFrame(),
                         comp_params_2d)[end-1]) < 1
end

@testset "comp_test tests" begin
    @test std(comp_test(xyz,ind_test;comp_params=comp_params_1 ,
                        silent=true)[end-1]) < 1
    @test std(comp_test(xyz,ind_test;comp_params=comp_params_2a,
                        silent=true)[end-1]) < 1
    @test std(comp_test(xyz,ind_test;comp_params=comp_params_2b,
                        silent=true)[end-1]) < 1
    @test std(comp_test(xyz,ind_test;comp_params=comp_params_2c,
                        silent=true)[end-1]) < 1
    @test std(comp_test(xyz,ind_test;comp_params=comp_params_2d,
                        silent=true)[end-1]) < 1
    @test std(comp_test(line_test,df_line,df_flight,DataFrame(),
                        comp_params_1 ,silent=true)[end-1]) < 1
    @test std(comp_test(line_test,df_line,df_flight,DataFrame(),
                        comp_params_2a,silent=true)[end-1]) < 1
    @test std(comp_test(line_test,df_line,df_flight,DataFrame(),
                        comp_params_2b,silent=true)[end-1]) < 1
    @test std(comp_test(line_test,df_line,df_flight,DataFrame(),
                        comp_params_2c,silent=true)[end-1]) < 1
    @test std(comp_test(line_test,df_line,df_flight,DataFrame(),
                        comp_params_2d,silent=true)[end-1]) < 1
    @test_throws ErrorException comp_test(xyz,ind_test;
                                          comp_params=comp_params_nn_bad)
    @test_throws ErrorException comp_test(xyz,ind_test;
                                          comp_params=comp_params_lin_bad)
    @test_throws ErrorException comp_test(xyz,ind_test;
                                          comp_params=comp_params_nn_bad_drop)
    @test_throws ErrorException comp_test(line_test,df_line,df_flight,DataFrame(),
                                          comp_params_nn_bad)
    @test_throws ErrorException comp_test(line_test,df_line,df_flight,DataFrame(),
                                          comp_params_lin_bad)
    @test_throws ErrorException comp_test(line_test,df_line,df_flight,DataFrame(),
                                          comp_params_nn_bad_drop)
end

rm(drop_fi_bson*"_1.bson")
rm(drop_fi_bson*"_2.bson")
rm(drop_fi_bson*"_3.bson")
rm(drop_fi_bson*"_4.bson")

@testset "comp_m2bc_test tests" begin
    @test std(comp_m2bc_test(line_test,df_line,df_flight,DataFrame(),
                        comp_params_2b,silent=true)[end-1]) < 1
    @test std(comp_m2bc_test(line_test,df_line,df_flight,DataFrame(),
                        comp_params_2c,silent=true)[end-1]) < 1
end

terms       = [:p]
terms_A     = [:p,:i,:e]
batchsize   = 5
epoch_lbfgs = 1
k_pca       = 5
frac_train  = 1

comp_params_1  = MagNav.NNCompParams(model_type  = :m1,
                                     y_type      = :a,
                                     terms       = terms,
                                     terms_A     = terms_A,
                                     sub_igrf    = true,
                                     epoch_lbfgs = epoch_lbfgs,
                                     batchsize   = batchsize,
                                     k_pca       = k_pca,
                                     frac_train  = frac_train)
comp_params_2a = MagNav.NNCompParams(model_type=:m2a,
                                     y_type      = :a,
                                     terms       = terms,
                                     terms_A     = terms_A,
                                     sub_igrf    = true,
                                     epoch_lbfgs = epoch_lbfgs,
                                     batchsize   = batchsize,
                                     k_pca       = k_pca,
                                     frac_train  = frac_train)
comp_params_2b = MagNav.NNCompParams(model_type=:m2b,
                                     y_type      = :a,
                                     terms       = terms,
                                     terms_A     = terms_A,
                                     sub_igrf    = true,
                                     epoch_lbfgs = epoch_lbfgs,
                                     batchsize   = batchsize,
                                     k_pca       = k_pca,
                                     frac_train  = frac_train)
comp_params_2c = MagNav.NNCompParams(model_type=:m2c,
                                     y_type      = :e,
                                     terms       = terms,
                                     terms_A     = terms_A,
                                     epoch_lbfgs = epoch_lbfgs,
                                     batchsize   = batchsize,
                                     k_pca       = k_pca,
                                     frac_train  = frac_train)
comp_params_2d = MagNav.NNCompParams(model_type=:m2d,
                                     y_type      = :e,
                                     terms       = terms,
                                     terms_A     = terms_A,
                                     epoch_lbfgs = epoch_lbfgs,
                                     batchsize   = batchsize,
                                     k_pca       = k_pca,
                                     frac_train  = frac_train)

comp_params_TL         = MagNav.LinCompParams(model_type=:TL,y_type=:a)
comp_params_mod_TL     = MagNav.LinCompParams(model_type=:mod_TL,y_type=:a)
comp_params_map_TL     = MagNav.LinCompParams(model_type=:map_TL,y_type=:a,sub_igrf=true)
comp_params_elasticnet = MagNav.LinCompParams(model_type=:elasticnet,y_type=:a)
comp_params_plsr       = MagNav.LinCompParams(model_type=:plsr,y_type=:a,k_plsr=1)

perm_fi_csv = joinpath(@__DIR__,"perm_fi.csv")
comp_params_1_drop  = MagNav.NNCompParams(comp_params_1,drop_fi=true,
                      drop_fi_bson=drop_fi_bson,drop_fi_csv=drop_fi_csv)
comp_params_1_perm  = MagNav.NNCompParams(comp_params_1,perm_fi=true,
                      perm_fi_csv=perm_fi_csv)
comp_params_2c_drop = MagNav.NNCompParams(comp_params_2c,drop_fi=true,
                      drop_fi_bson=drop_fi_bson,drop_fi_csv=drop_fi_csv)
comp_params_2c_perm = MagNav.NNCompParams(comp_params_2c,perm_fi=true,
                      perm_fi_csv=perm_fi_csv)

@testset "comp_train_test tests" begin
    for comp_params in [comp_params_1,comp_params_2a,comp_params_2b,
                        comp_params_2c,comp_params_2d,comp_params_TL,
                        comp_params_mod_TL,comp_params_map_TL,
                        comp_params_elasticnet,comp_params_plsr,
                        comp_params_1_drop,comp_params_2c_drop,
                        comp_params_1_perm,comp_params_2c_perm]
        @test std(comp_train_test(xyz,xyz,ind_train,ind_test,mapS,mapS;
                                  comp_params=comp_params)[end-1]) ≈ 
              std(comp_train_test(line_train,line_test,df_line,df_flight,
                                  df_map,comp_params)[end-1])
    end
end

@testset "print_time tests" begin
    @test typeof(MagNav.print_time(30)) == Nothing
    @test typeof(MagNav.print_time(90)) == Nothing
end

rm(drop_fi_bson*"_1.bson")
rm(drop_fi_bson*"_2.bson")
rm(drop_fi_bson*"_3.bson")
rm(drop_fi_bson*"_4.bson")
rm(drop_fi_csv)
rm(perm_fi_csv)
rm(map_h5)
