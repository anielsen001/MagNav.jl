"""
    get_XYZ20(xyz_h5::String; tt_sort::Bool=true, silent::Bool=false)

Get `XYZ20` flight data from saved HDF5 file. Based on SGL 2020 data fields.

**Arguments:**
- `xyz_h5`:  path/name of HDF5 file containing flight data
- `tt_sort`: (optional) if true, sort data by time (instead of line)
- `silent`:  (optional) if true, no print outs

**Returns:**
- `xyz`: `XYZ20` flight data struct
"""
function get_XYZ20(xyz_h5::String; tt_sort::Bool=true, silent::Bool=false)

    fields = :fields20

    silent || @info("reading in data: $xyz_h5")

    xyz = h5open(xyz_h5,"r") # read-only
    N   = maximum([length(read(xyz,k)) for k in keys(xyz)])
    d   = Dict()
    ind = tt_sort ? sortperm(read_check(xyz,:tt,N,silent)) : trues(N)

    for field in xyz_fields(fields)
        field != :ignore && push!(d,field=>read_check(xyz,field,N,silent)[ind])
    end

    close(xyz)

    dt = N > 1 ? round(d[:tt][2] - d[:tt][1]; digits=9) : 0.1

    # using [rad] exclusively
    for field in [:lat,:lon,:ins_roll,:ins_pitch,:ins_yaw,
                  :roll_rate,:pitch_rate,:yaw_rate]
        push!(d,field => deg2rad.(d[field]))
    end

    # provided IGRF for convenience
    push!(d,:igrf => d[:mag_1_dc] - d[:mag_1_igrf])

    # trajectory velocities and specific forces from position
    push!(d,:vn =>  fdm(d[:utm_y]) / dt)
    push!(d,:ve =>  fdm(d[:utm_x]) / dt)
    push!(d,:vd => -fdm(d[:utm_z]) / dt)
    push!(d,:fn =>  fdm(d[:vn])    / dt)
    push!(d,:fe =>  fdm(d[:ve])    / dt)
    push!(d,:fd =>  fdm(d[:vd])    / dt .- g_earth)

    # Cnb direction cosine matrix (body to navigation) from yaw, pitch, roll
    push!(d,:Cnb     => zeros(3,3,N)) # unknown
    push!(d,:ins_Cnb => euler2dcm(d[:ins_roll],d[:ins_pitch],d[:ins_yaw],:body2nav))
    push!(d,:ins_P   => zeros(1,1,N)) # unknown

    # INS velocities in NED direction
    push!(d,:ins_ve => -d[:ins_vw])
    push!(d,:ins_vd => -d[:ins_vu])

    # INS specific forces from measurements, rotated wander angle (CW for NED)
    ins_f = zeros(N,3)
    for i = 1:N
        ins_f[i,:] = euler2dcm(0,0,-d[:ins_wander][i],:body2nav) * 
                     [d[:ins_acc_x][i],-d[:ins_acc_y][i],-d[:ins_acc_z][i]]
    end

    push!(d,:ins_fn => ins_f[:,1])
    push!(d,:ins_fe => ins_f[:,2])
    push!(d,:ins_fd => ins_f[:,3])

    # INS specific forces from finite differences
    # push!(d,:ins_fn => fdm(-d[:ins_vn]) / dt)
    # push!(d,:ins_fe => fdm(-d[:ins_ve]) / dt)
    # push!(d,:ins_fd => fdm(-d[:ins_vd]) / dt .- g_earth)

    return XYZ20(Traj(N,  dt, d[:tt], d[:lat], d[:lon], d[:utm_z], d[:vn],
                      d[:ve], d[:vd], d[:fn] , d[:fe] , d[:fd]   , d[:Cnb]),
                INS( N, dt, d[:tt], d[:ins_lat], d[:ins_lon], d[:ins_alt],
                     d[:ins_vn]   , d[:ins_ve] , d[:ins_vd] , d[:ins_fn] ,
                     d[:ins_fe]   , d[:ins_fd] , d[:ins_Cnb], d[:ins_P]),
                MagV(d[:flux_a_x], d[:flux_a_y], d[:flux_a_z], d[:flux_a_t]),
                MagV(d[:flux_b_x], d[:flux_b_y], d[:flux_b_z], d[:flux_b_t]),
                MagV(d[:flux_c_x], d[:flux_c_y], d[:flux_c_z], d[:flux_c_t]),
                MagV(d[:flux_d_x], d[:flux_d_y], d[:flux_d_z], d[:flux_d_t]),
                d[:flight]    , d[:line]      , d[:utm_x]     , d[:utm_y]     ,
                d[:utm_z]     , d[:msl]       , d[:baro]      , d[:diurnal]   ,
                d[:igrf]      , d[:mag_1_c]   , d[:mag_1_lag] , d[:mag_1_dc]  ,
                d[:mag_1_igrf], d[:mag_1_uc]  , d[:mag_2_uc]  , d[:mag_3_uc]  ,
                d[:mag_4_uc]  , d[:mag_5_uc]  , d[:mag_6_uc]  , d[:ogs_mag]   ,
                d[:ogs_alt]   , d[:ins_wander], d[:ins_roll]  , d[:ins_pitch] ,
                d[:ins_yaw]   , d[:roll_rate] , d[:pitch_rate], d[:yaw_rate]  ,
                d[:ins_acc_x] , d[:ins_acc_y] , d[:ins_acc_z] , d[:lgtl_acc]  ,
                d[:ltrl_acc]  , d[:nrml_acc]  , d[:pitot_p]   , d[:static_p]  ,
                d[:total_p]   , d[:cur_com_1] , d[:cur_ac_hi] , d[:cur_ac_lo] ,
                d[:cur_tank]  , d[:cur_flap]  , d[:cur_strb]  , d[:cur_srvo_o],
                d[:cur_srvo_m], d[:cur_srvo_i], d[:cur_heat]  , d[:cur_acpwr] ,
                d[:cur_outpwr], d[:cur_bat_1] , d[:cur_bat_2] , d[:vol_acpwr] ,
                d[:vol_outpwr], d[:vol_bat_1] , d[:vol_bat_2] , d[:vol_res_p] ,
                d[:vol_res_n] , d[:vol_back_p], d[:vol_back_n], d[:vol_gyro_1],
                d[:vol_gyro_2], d[:vol_acc_p] , d[:vol_acc_n] , d[:vol_block] ,
                d[:vol_back]  , d[:vol_srvo]  , d[:vol_cabt]  , d[:vol_fan]   )
end # function get_XYZ20

"""
    get_XYZ21(xyz_h5::String; tt_sort::Bool=true, silent::Bool=false)

Get `XYZ21` flight data from saved HDF5 file. Based on SGL 2021 data fields.

**Arguments:**
- `xyz_h5`:  path/name of HDF5 file containing flight data
- `tt_sort`: (optional) if true, sort data by time (instead of line)
- `silent`:  (optional) if true, no print outs

**Returns:**
- `xyz`: `XYZ21` flight data struct
"""
function get_XYZ21(xyz_h5::String; tt_sort::Bool=true, silent::Bool=false)

    fields = :fields21

    silent || @info("reading in data: $xyz_h5")

    xyz = h5open(xyz_h5,"r") # read-only
    N   = maximum([length(read(xyz,k)) for k in keys(xyz)])
    d   = Dict()
    ind = tt_sort ? sortperm(read_check(xyz,:tt,N,silent)) : trues(N)

    for field in xyz_fields(fields)
        field != :ignore && push!(d,field=>read_check(xyz,field,N,silent)[ind])
    end

    close(xyz)

    dt = N > 1 ? round(d[:tt][2] - d[:tt][1]; digits=9) : 0.1

    # using [rad] exclusively
    for field in [:lat,:lon,:ins_roll,:ins_pitch,:ins_yaw]
        push!(d,field => deg2rad.(d[field]))
    end

    # provided IGRF for convenience
    push!(d,:igrf => d[:mag_1_dc] - d[:mag_1_igrf])

    # trajectory velocities and specific forces from position
    push!(d,:vn =>  fdm(d[:utm_y]) / dt)
    push!(d,:ve =>  fdm(d[:utm_x]) / dt)
    push!(d,:vd => -fdm(d[:utm_z]) / dt)
    push!(d,:fn =>  fdm(d[:vn])    / dt)
    push!(d,:fe =>  fdm(d[:ve])    / dt)
    push!(d,:fd =>  fdm(d[:vd])    / dt .- g_earth)

    # Cnb direction cosine matrix (body to navigation) from yaw, pitch, roll
    push!(d,:Cnb     => zeros(3,3,N)) # unknown
    push!(d,:ins_Cnb => euler2dcm(d[:ins_roll],d[:ins_pitch],d[:ins_yaw],:body2nav))
    push!(d,:ins_P   => zeros(1,1,N)) # unknown

    # INS velocities in NED direction
    push!(d,:ins_ve => -d[:ins_vw])
    push!(d,:ins_vd => -d[:ins_vu])

    # INS specific forces from measurements, rotated wander angle (CW for NED)
    ins_f = zeros(N,3)
    for i = 1:N
        ins_f[i,:] = euler2dcm(0,0,-d[:ins_wander][i],:body2nav) * 
                     [d[:ins_acc_x][i],-d[:ins_acc_y][i],-d[:ins_acc_z][i]]
    end

    push!(d,:ins_fn => ins_f[:,1])
    push!(d,:ins_fe => ins_f[:,2])
    push!(d,:ins_fd => ins_f[:,3])

    # INS specific forces from finite differences
    # push!(d,:ins_fn => fdm(-d[:ins_vn]) / dt)
    # push!(d,:ins_fe => fdm(-d[:ins_ve]) / dt)
    # push!(d,:ins_fd => fdm(-d[:ins_vd]) / dt .- g_earth)

    return XYZ21(Traj(N,  dt, d[:tt], d[:lat], d[:lon], d[:utm_z], d[:vn],
                      d[:ve], d[:vd], d[:fn] , d[:fe] , d[:fd]   , d[:Cnb]),
                INS( N, dt, d[:tt], d[:ins_lat], d[:ins_lon], d[:ins_alt],
                     d[:ins_vn]   , d[:ins_ve] , d[:ins_vd] , d[:ins_fn] ,
                     d[:ins_fe]   , d[:ins_fd] , d[:ins_Cnb], d[:ins_P]),
                MagV(d[:flux_a_x], d[:flux_a_y], d[:flux_a_z], d[:flux_a_t]),
                MagV(d[:flux_b_x], d[:flux_b_y], d[:flux_b_z], d[:flux_b_t]),
                MagV(d[:flux_c_x], d[:flux_c_y], d[:flux_c_z], d[:flux_c_t]),
                MagV(d[:flux_d_x], d[:flux_d_y], d[:flux_d_z], d[:flux_d_t]),
                d[:flight]    , d[:line]      , d[:year]      , d[:doy]       ,
                d[:utm_x]     , d[:utm_y]     , d[:utm_z]     , d[:msl]       ,
                d[:baro]      , d[:diurnal]   , d[:igrf]      , d[:mag_1_c]   ,
                d[:mag_1_uc]  , d[:mag_2_uc]  , d[:mag_3_uc]  , d[:mag_4_uc]  ,
                d[:mag_5_uc]  , d[:cur_com_1] , d[:cur_ac_hi] , d[:cur_ac_lo] ,
                d[:cur_tank]  , d[:cur_flap]  , d[:cur_strb]  , d[:vol_block] ,
                d[:vol_back]  , d[:vol_cabt]  , d[:vol_fan]   )
end # function get_XYZ21

"""
    get_XYZ(flight::Symbol, df_flight::DataFrame;
            tt_sort::Bool=true, silent::Bool=false)

Get `XYZ` flight data from saved HDF5 file via DataFrame lookup.

**Arguments:**
- `flight`: name of flight data
- `df_flight`: lookup table (DataFrame) of flight files
- `tt_sort`: (optional) if true, sort data by time (instead of line)
- `silent`:  (optional) if true, no print outs

**Returns:**
- `xyz`: `XYZ` flight data struct
"""
function get_XYZ(flight::Symbol, df_flight::DataFrame;
                 tt_sort::Bool=true, silent::Bool=false)
    ind = findfirst(df_flight.flight .== flight)
    if df_flight.xyz_type[ind] == :XYZ20
        get_XYZ20(df_flight.xyz_h5[ind];tt_sort=tt_sort,silent=silent)
    elseif df_flight.xyz_type[ind] == :XYZ21
        get_XYZ21(df_flight.xyz_h5[ind];tt_sort=false,silent=silent)
    end
end # function get_XYZ

"""
    read_check(xyz::HDF5.File, field::Symbol, N::Int=1, silent::Bool=false)

Check for NaNs or missing data (returned as NaNs) in HDF5 file containing 
flight data. Prints out warning for any field that contains NaNs.

**Arguments:**
- `xyz`:    opened HDF5 file with flight data
- `field`:  data field to read
- `N`:      number of samples (instances)
- `silent`: (optional) if true, no print outs

**Returns:**
- `val`: data returned for `field`
"""
function read_check(xyz::HDF5.File, field::Symbol, N::Int=1, silent::Bool=false)
    field = string.(field)
    if field in keys(xyz)
        val = read(xyz,field)
        !any(isnan.(val)) || silent || @info("$field field contains NaNs")
    else
        val = zeros(N)*NaN
        silent || @info("$field field contains NaNs")
    end
    return (val)
end # function read_check
