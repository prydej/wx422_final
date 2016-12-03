load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

; Avoid the issue of no input options with the next line 
if (.not. isvar ("debug")) then
  debug = 0 ; minimal I/O for scipted environment
  debug = 1 ; Give status updates throughout
  debug = 2 ; Give details about data and variables
;  debug = 3 ; What more do you want?  
;  debug = 4 ; I used >3 down there!
end if ; Now we have debug set

;
; Setup date strings
today = systemfunc("date -u  +%Y%m%d")
yesterday = systemfunc("date -u -d yesterday +%Y%m%d")

; Use these as desired
; Should add code to use yesterday if today isn't found.  Done!
;myDate = today
;myDate = yesterday

; Check to see if date is already set.  If not, set it here
; Could be set via command line syntax.  See NCL documentation
if (.not. isvar("myDate"))then
  myDate = today ; If today doesn't work, we will try yesterday too.
end if

;
; Here is a URL that will get the averages from the NAEFS 
; A generic script could have this as a commandline input, or 
; in a text file to eliminate the issue of special characters in the URL.
;
;dset = "geavg_00z"
;dset = "ge10pt_00z"
;dset = "ge90pt_00z"
;dset = "gespr_00z"
;dset = "gemode_00z"
dset = "ge50pt_00z"


NOMADS = "http://nomads.ncep.noaa.gov:9090/dods/naefs_bc/naefs"+myDate+"/"+dset


filename = NOMADS ; = url 
if (debug .gt. 0) then
  print("Fetching URL: ")
  print(" "+filename)
end if

exists = isfilepresent(filename)
if(.not.exists) then 
; This error prints for all debug levels
  print("OPeNDAP file not found for "+today)
  print("Checking for "+yesterday)
  myDate = yesterday
  NOMADS = "http://nomads.ncep.noaa.gov:9090/dods/naefs_bc/naefs"+myDate+"/"+dset
  filename = NOMADS ; = url 
  print("Fetching older URL: ")
  print(" "+filename)
  exists = isfilepresent(filename)
  if(.not.exists) then
    print("Second attempt to open the file with older date failed!")
    print("Something is wrong with the filename or server.")
    print("Either file doesn't exist, or NCL does not have OPeNDAP capabilities on this system")
    exit ; We have no data to process Consider an error code here.
  end if
  
end if

if (debug .gt. 0) then
  print("OPeNDAP isfilepresent test successful.")
end if

f = addfile(filename,"r")
vars = getfilevarnames(f)
; Print the inventory of the data
if (debug .gt. 1) then
  print(vars)   ; should be (in any order): 
end if

if (debug .gt. 3) then
  if(.not.any(ismissing(vars))) then
    do i=0,dimsizes(vars)-1
      printFileVarSummary (f,vars(i))
    end do
  end if
end if


;;;;;;
;
; Now we know we have access to some data
;
;;;;;;;

; exit ; Bail out for testing purposes.

; Define boundary of data
; Assign lat/lon boundaries to the data

;
myNlat = 60.0
mySlat = 10.0
myWlon = 230.0 ; -130
myElon = 310.0 ; -50

;myNlat = 90.0
;mySlat = -90.0
;myWlon = 0.0
;myElon = 359.0



; Get lat/lon/time info first
lat = f->lat
print ("Done reading lat")
lon = f->lon
print ("Done reading lon")
time = f->time
print ("Done reading time")
ens = f->ens
print ("Done reading ens")
;

Nlat = closest_val(myNlat, lat)
print ("Nlat = " + Nlat + " Lat = " + lat(Nlat) )

Slat = closest_val(mySlat, lat)
print ("Slat = " + Slat + " Lat = " + lat(Slat) )

Wlon = closest_val(myWlon, lon)
print("Wlon = " + Wlon + " Lon = " + lon(Wlon) )

Elon = closest_val(myElon, lon)
print("Elon = " + Elon + " Lon = " + lon(Elon) )
;
;exit
;
mylat = lat(Slat:Nlat)
mylon = lon(Wlon:Elon)

;printVarSummary (mylat)
;printVarSummary (mylon)

;;exit


delete(lat)
delete(lon)

lat = f->lat(Slat:Nlat)
lon = f->lon(Wlon:Elon)
print ("Done reading subset lat/lon")
;printVarSummary(lat)
;printVarSummary(lon)


; Here we open a NetCDF file for output.  
; First delete any file that might already exist
if (isfilepresent(myDate+"_naefs_avg.nc")) then
  print("Removing old file")
  system("/bin/rm "+myDate+"_naefs_avg.nc")
end if

ncdf = addfile(myDate+"_"+dset+".nc" ,"c")  ; open output netCDF file

;===================================================================
; create global attributes of the file (optional)
;===================================================================
fAtt               = True            ; assign file attributes
fAtt@title         = "NCL Simple Approach to netCDF Creation"
fAtt@source_file   =  NOMADS
fAtt@Conventions   = "None"
fAtt@creation_date = systemfunc ("date")
fileattdef( ncdf, fAtt )            ; copy file attributes

;===================================================================
; make time an UNLIMITED dimension; recommended  for most applications
;===================================================================
;filedimdef(ncdf,"time",-1,True) 

;===================================================================
; output variables directly; NCL will call appropriate functions
; to write the meta data associated with each variable
;===================================================================
ncdf->ens  = ens
ncdf->time = time
; First set max and min attributes for the boundaries
lat@minimum = min(lat)
lat@maximum = max(lat)
ncdf->lat  = lat

lon@minimum = min(lon)
lon@maximum = max(lon)
ncdf->lon  = lon

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
if(debug .gt. 0) then
  print (" ")
  print (" ")
  print ("Starting to read all times for data")
end if

; ================================================================
; Here is a list of variables that we might want to use, valid 
; for the example NAEFS dataset.
; We need to modify the code below to get each one with a list 
; given to this script, perhaps from a text file populated by a 
; controlling script/driver.
;
;rh2m
;ugrd10m
;vgrd10m
;dpt2m
;tmp2m
;
; ================================================================

; Get all ens (1) and time (65) elements
rh2m = f->rh2m(:,:,Slat:Nlat,Wlon:Elon)
if(debug .gt. 0) then
  print ("Done reading rh2m")
end if

if(debug .gt. 1) then
  print("Local variable to be exported")
  printVarSummary(rh2m)
end if

ncdf->rh2m = rh2m

if(debug .gt. 4) then
  print (rh2m)
end if


dpt2m = f->dpt2m(:,:,Slat:Nlat,Wlon:Elon)
if(debug .gt. 0) then
  print ("Done reading dpt2m")
end if
;printVarSummary(dpt2m)
;  sst@long_name = "SST (C)" ; Use my name in the plot sub-title

ncdf->dpt2m = dpt2m
;print (sst)


tmp2m = f->tmp2m(:,:,Slat:Nlat,Wlon:Elon)
if(debug .gt. 0) then
  print ("Done reading tmp2m")
end if

;printVarSummary(tmp2m)
;  sst@long_name = "SST (C)" ; Use my name in the plot sub-title

ncdf->tmp2m = tmp2m
;print (sst)


ugrd10m = f->ugrd10m(:,:,Slat:Nlat,Wlon:Elon)
;ugrd10m = f->ugrd10m
if(debug .gt. 0) then
  print ("Done reading U")
end if

;printVarSummary(ugrd10m)
;print (ugrd10m)

ncdf->ugrd10m = ugrd10m

vgrd10m = f->vgrd10m(:,:,Slat:Nlat,Wlon:Elon)
;vgrd10m = f->vgrd10m
if(debug .gt. 0) then
  print ("Done reading V")
end if

;printVarSummary(vgrd10m)
;print (vgrd10m)

ncdf->vgrd10m = vgrd10m

;
;Convert vectors to speed in knots
;speed = u_velocity ; create array with metadata
speed = sqrt((ugrd10m^2)+(vgrd10m^2)) * 1.9438
copy_VarCoords(ugrd10m,speed); copies coodrinate arrays to speed
speed@long_name = "Wind Speed (kts)"
speed@units = "knots"

if(debug .gt. 0) then
  print ("Done calculating Speed")
end if

;print (speed)

ncdf->speed = speed

;
;=========================================================================
; This is included here as code sample, but probably should bbbe moved to 
; another script with an array of locations, not just one.  We should talk.
;
myLocLat = 29.1849
myLocLon = -81.0607 ; For western longitude use negative

if (myLocLon .lt. 0.0) then
  myLocLon = myLocLon + 360 ; Converts to degrees East
end if


;  ===  There are test code pieces here ===
; These prints violate the debug paradigm until I know more about 
; the differences in these functions.

;LatIndex = ind_nearest_coord(myLocLat,lat,0)
;LonIndex = ind_nearest_coord(myLocLon,lon,0)
;
;print("First method lat/lon index "+LatIndex+", "+LonIndex)

LatIndex = closest_val(myLocLat,lat)
LonIndex = closest_val(myLocLon,lon)

print("lat/lon index "+LatIndex+", "+LonIndex)
;
; My experiment yielded the same result.  I think method two is more general,
; but I'll be happy to hear your interpretation if different.
; =============================================================
;
if (debug .gt. 1)
  print ("tmp2m for location")
  print ("There are "+num(.not.ismissing(tmp2m(0,:,LatIndex,LonIndex)))+" valid points out of "+dimsizes(tmp2m(0,:,LatIndex,LonIndex)))
;
; Convert to Celsius, note that math is not done on values = FillValue
  tmpC2m = tmp2m - 273.15
;  print (tmp2m(:,:,LatIndex,LonIndex))
;  print ("                              ")
;  print (tmpC2m(:,:,LatIndex,LonIndex))
  
  print ("                              ")
; Finished fetching data
  print (" ")
; This is here for an example of working with time
format = ""
stime = cd_string(time,format)

;print (stime)
;print (dimsizes(time))

do i=0,dimsizes(time)-1
  print (i+", "+stime(i)+", "+tmpC2m(0,i,LatIndex,LonIndex))
end do

print (" All Done ")
print (" ")

end if
