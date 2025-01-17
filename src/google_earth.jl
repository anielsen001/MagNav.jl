"""
    map2kmz(map_map::Matrix, map_xx::Vector, map_yy::Vector,
            map_name::String  = "map";
            map_units::Symbol = :rad,
            plot_alt          = 0,
            opacity           = 0.75,
            clims::Tuple      = (0,0))

Create kmz file of map for use with Google Earth. Generates an "icon" overlay, 
and is thus not meant for large maps (e.g. > 5 deg x 5 deg).

**Arguments:**
- `map_map`:   `ny` x `nx` 2D gridded map data
- `map_xx`:    `nx` x-direction (longitude) map coordinates [rad] or [deg]
- `map_yy`:    `ny` y-direction (latitude)  map coordinates [rad] or [deg]
- `map_name`:  (optional) map name to save
- `map_units`: (optional) map xx/yy units {`:rad`,`:deg`}
- `plot_alt`:  (optional) map altitude in Google Earth [m]
- `opacity`:   (optional) map opacity {0:1}
- `clims`:     (optional) map color scale limits

**Returns:**
- `nothing`: kmz file `map_name`.kmz is created
"""
function map2kmz(map_map::Matrix, map_xx::Vector, map_yy::Vector,
                 map_name::String  = "map";
                 map_units::Symbol = :rad,
                 plot_alt          = 0,
                 opacity           = 0.75,
                 clims::Tuple      = (0,0))

    if map_units == :rad
        map_west  = rad2deg(minimum(map_xx))
        map_east  = rad2deg(maximum(map_xx))
        map_south = rad2deg(minimum(map_yy))
        map_north = rad2deg(maximum(map_yy))
    elseif map_units == :deg
        map_west  = minimum(map_xx)
        map_east  = maximum(map_xx)
        map_south = minimum(map_yy)
        map_north = maximum(map_yy)
    else
        error("$map_units map xx/yy units not defined")
    end

    map_kml   = string(map_name,".kml")
    map_kmz   = string(map_name,".kmz")
    map_png   = string(map_name,".png")
    map_trans = string(string(round(Int,opacity*255),base=16),"ffffff") # ABGR

    p1  = plot_map(map_map;
                   clims     = clims,
                   dpi       = 200,
                   margin    = -2, # includes 2mm otherwise
                   legend    = false,
                   axis      = false,
                   fewer_pts = false,
                   bg_color  = :transparent)

    plot!(p1,size=min.(size(map_map),10000))

    png(p1,map_name)

    open(map_kml,"w") do file
        println(file,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?> \n",
        "<kml xmlns=\"http://www.opengis.net/kml/2.2\" xmlns:gx=\"http://www.google.com/kml/ext/2.2\" xmlns:kml=\"http://www.opengis.net/kml/2.2\" xmlns:atom=\"http://www.w3.org/2005/Atom\"> \n",
        "  <Document> ")

        println(file,
        "    <Folder> \n",
        "      <GroundOverlay> \n",
        "        <Icon> \n",
        "          <href>",map_png,"</href> \n",
        "        </Icon> \n",
        "        <color>",map_trans,"</color> ")
        if plot_alt > 0 # put map at altitude specified, otherwise ground
        println(file,
        "        <altitude>",plot_alt,"</altitude> \n",
        "   	   <altitudeMode>absolute</altitudeMode> ")
        end
        println(file,
        "        <LatLonBox> \n",
        "          <north>",map_north,"</north> \n",
        "          <south>",map_south,"</south> \n",
        "          <east>",map_east,"</east> \n",
        "          <west>",map_west,"</west> \n",
        "          <rotation>0</rotation> \n",
        "        </LatLonBox> \n",
        "      </GroundOverlay> \n",
        "    </Folder> ")

        println(file,
        "  </Document> \n",
        "</kml> ")
    end

    w = ZipFile.Writer(map_kmz)

    for file in [map_kml,map_png]
        f = ZipFile.addfile(w,file,method=ZipFile.Deflate)
        write(f,read(file))
    end

    close(w)
    rm(map_kml)
    rm(map_png)

end # function map2kmz

"""
    map2kmz(mapS::Union{MapS,MapSd},
            map_name::String = "map";
            plot_alt         = 0,
            opacity          = 0.75,
            clims::Tuple     = (0,0))

Create kmz file of map for use with Google Earth. Generates an "icon" overlay, 
and is thus not meant for large maps (e.g. > 5 deg x 5 deg).

**Arguments:**
- `mapS`:      `MapS` or `MapSd` scalar magnetic anomaly map struct
- `map_name`:  (optional) map name to save
- `plot_alt`:  (optional) map altitude in Google Earth [m]
- `opacity`:   (optional) map opacity {0:1}
- `clims`:     (optional) map color scale limits

**Returns:**
- `nothing`: kmz file `map_name`.kmz is created
"""
function map2kmz(mapS::Union{MapS,MapSd},
                 map_name::String = "map";
                 plot_alt         = 0,
                 opacity          = 0.75,
                 clims::Tuple     = (0,0))
    map2kmz(mapS.map,mapS.xx,mapS.yy,map_name;
            map_units = :rad,
            plot_alt  = plot_alt,
            opacity   = opacity,
            clims     = clims)
end # function map2kmz

"""
    path2kml(lat::Vector, lon::Vector, alt::Vector,
             path_name::String  = "path";
             path_units::Symbol = :rad,
             width::Int         = 3,
             color1::String     = "ff000000",
             color2::String     = "80000000",
             points::Bool       = false)

Create kml file of flight path for use with Google Earth.

**Arguments:**
- `lat`:        latitude  [rad] or [deg]
- `lon`:        longitude [rad] or [deg]
- `alt`:        altitude  [m]
- `path_name`:  (optional) flight path name
- `path_units`: (optional) `lat`/`lon` units {`:rad`,`:deg`}
- `width`:      (optional) line width
- `color1`:     (optional) path color
- `color2`:     (optional) below-path color
- `points`      (optional) if true, create points instead of line

**Returns:**
- `nothing`: kml file `path_name`.kml is created
"""
function path2kml(lat::Vector, lon::Vector, alt::Vector,
                  path_name::String  = "path";
                  path_units::Symbol = :rad,
                  width::Int         = 3,
                  color1::String     = "ff000000",
                  color2::String     = "80000000",
                  points::Bool       = false)

    # color1 = "ff000000" # ABGR black
    # color1 = "ffff0000" # ABGR blue
    # color1 = "ff00ff00" # ABGR green
    # color1 = "ff0000ff" # ABGR red

    N   = length(lat) # maximum number of points
    lim = points ? 1000 : 30000 # set points limit
    frac = N > lim ? ceil(Int,N/lim) : 1 # use to avoid Google Earth issues

    if path_units == :rad
        lat = rad2deg.(lat)
        lon = rad2deg.(lon)
    elseif path_units != :deg
        error("$path_units lat/lon units not defined")
    end

    path_kml = string(path_name,".kml")

    if points
        open(path_kml,"w") do file
            println(file,
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?> \n",
            "<kml xmlns=\"http://www.opengis.net/kml/2.2\" xmlns:gx=\"http://www.google.com/kml/ext/2.2\" xmlns:kml=\"http://www.opengis.net/kml/2.2\" xmlns:atom=\"http://www.w3.org/2005/Atom\"> \n",
            "  <Document> \n",
            "    <Folder> ")

            for i = 1:frac:N
            println(file,
            "      <Placemark> \n",
            "        <visibility>1</visibility> \n",
            "        <Point> \n",
            "          <coordinates>",
            lon[i],",",lat[i],",",alt[i],"</coordinates> \n",
            "        </Point> \n",
            "        <Model> \n",
            "          <altitudeMode>relativeToGround</altitudeMode> \n",
            "          <Location><longitude>",
            lon[i],"</longitude><latitude>",lat[i],"</latitude><altitude>",alt[i],"</altitude></Location> \n",
            "            <Scale><x>50</x><y>50</y><z>1</z></Scale> \n",
            "          <Link><href>$icon_circle</href></Link> \n",
            "        </Model> \n",
            "      </Placemark> ")
            end

            println(file,
            "    </Folder> \n",
            "  </Document> \n",
            "</kml> ")
        end
    else
        open(path_kml,"w") do file
            println(file,
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?> \n",
            "<kml xmlns=\"http://www.opengis.net/kml/2.2\" xmlns:gx=\"http://www.google.com/kml/ext/2.2\" xmlns:kml=\"http://www.opengis.net/kml/2.2\" xmlns:atom=\"http://www.w3.org/2005/Atom\"> \n",
            "  <Document> ")

            println(file,
            "    <Style id=\"line1-normal\"> \n",
            "      <LineStyle> \n",
            "        <color>",color1,"</color> \n",
            "        <width>",width,"</width> \n",
            "      </LineStyle> \n",
            "      <PolyStyle> \n",
            "        <color>",color2,"</color> \n",
            "        <outline>0</outline> \n",
            "      </PolyStyle> \n",
            "      <BalloonStyle> \n",
            "        <text><![CDATA[<h3>\$[name]</h3>]]></text> \n",
            "      </BalloonStyle> \n",
            "    </Style> \n",
            "    <Style id=\"line1-highlight\"> \n",
            "      <LineStyle> \n",
            "        <color>",color1,"</color> \n",
            "        <width>",1.5*width,"</width> \n",
            "      </LineStyle> \n",
            "      <PolyStyle> \n",
            "        <color>",color2,"</color> \n",
            "        <outline>0</outline> \n",
            "      </PolyStyle> \n",
            "      <BalloonStyle> \n",
            "        <text><![CDATA[<h3>\$[name]</h3>]]></text> \n",
            "      </BalloonStyle> \n",
            "    </Style> \n",
            "    <StyleMap id=\"line1\"> \n",
            "      <Pair> \n",
            "        <key>normal</key> \n",
            "        <styleUrl>#line1-normal</styleUrl> \n",
            "      </Pair> \n",
            "      <Pair> \n",
            "        <key>highlight</key> \n",
            "        <styleUrl>#line1-highlight</styleUrl> \n",
            "      </Pair> \n",
            "    </StyleMap> ")

            println(file,
            "    <Folder> \n",
            "      <Placemark> \n",
            "        <name>aircraft path</name> \n",
            "        <styleUrl>#line1</styleUrl> \n",
            "        <LineString> \n",
            "          <extrude>1</extrude> \n",
            "          <tessellate>1</tessellate> \n",
            "          <altitudeMode>relativeToGround</altitudeMode> \n",
            "          <coordinates> ")
            for i = 1:frac:N
                println(file,"            ",lon[i],",",lat[i],",",alt[i])
            end
            println(file,
            "          </coordinates> \n",
            "        </LineString> \n",
            "      </Placemark> \n",
            "    </Folder> ")

            println(file,
            "  </Document> \n",
            "</kml> ")
        end
    end
end # function path2kml

"""
    path2kml(path::Path,
             path_name::String = "path";
             width::Int        = 3,
             color1::String    = "",
             color2::String    = "00ffffff",
             points::Bool      = false)

Create kml file of flight path for use with Google Earth.

**Arguments:**
- `path`:      `Path` struct, i.e. `Traj` trajectory struct, `INS` inertial navigation system struct, or `FILTout` filter extracted output struct
- `path_name`: (optional) flight path name
- `width`:     (optional) line width
- `color1`:    (optional) path color
- `color2`:    (optional) below-path color
- `points`     (optional) if true, create points instead of line

**Returns:**
- `nothing`: kml file `path_name`.kml is created
"""
function path2kml(path::Path,
                  path_name::String = "path";
                  width::Int        = 3,
                  color1::String    = "",
                  color2::String    = "00ffffff",
                  points::Bool      = false)

    if color1 == ""
        typeof(path) == Traj    && (color1 = "ffff8500")
        typeof(path) == INS     && (color1 = "ff2b50ec")
        typeof(path) == FILTout && (color1 = "ff319b00")
    end

    color1 in ["black","k"] && (color1 = "ff000000")
    color2 in ["black","k"] && (color2 = "80000000")

    path2kml(path.lat,path.lon,path.alt,path_name;
             path_units = :rad,
             width      = width,
             color1     = color1,
             color2     = color2,
             points     = points)
end # function path2kml
