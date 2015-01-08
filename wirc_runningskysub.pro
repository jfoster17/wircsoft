; note - timeradius is equal to the half-width
;  went for IO-intensive solution
;  otherwise memory demands might be too high to be accomodated.
;
; cognoscenti will recognize descent from dim-sum
;
; 1/06/15  Branch version to handle separate
;          sky and object images JBF
; 4/29/08  cal file handling re-written  JAS
; 5/01/08  added file compression option
;          stopped saving sky frames by default
; 5/15/08  added some logic for multiple coadds JAS
; 5/29/08  fixed a problem in the where statement for sextractor
;
;
pro wirc_runningskysub,inlist,$ ;list of all frames
                       timeradius,$ ; radius (in images) forward and back
                       RUN=RUN,$ ; should be 1 or 2
                       FLATFILE=FLATFILE,$ ; alternative flatfield
                       DARKFILE=DARKFILE,$ ; alternative dark
                       NOQUADCLEAN=NOQUADCLEAN,$ ; don't run quadrant scrubber
                       SAVESKY=SAVESKY,$ ; save the sky files
                       COMPRESS=COMPRESS ; gzip all output files

; the RUN keyword indicates if this is the first pass for mask generation
if (keyword_set(RUN) NE 1) then RUN=1


; get the time
start_time=systime(/seconds)

; convolution kernel for growing the masks
kernel=fltarr(5,5)
kernel[*]=1

yo = strsplit(inlist,'.',/extract)

skylist = yo[0]+"_sky.list"
objlist = yo[0]+"_obj.list"

; read in the input lists
readcol,skylist,skyfile,format="a"
readcol,objlist,objfile,format="a"
readcol,inlist,infile,format="a"

nobjfiles=n_elements(objfile)
nskyfiles=n_elements(skyfile)
objlen = nobjfiles
skylen = nskyfiles
; this list will be manipulated to decide which files get included 
; for the sky subtraction
mod_sky_list=intarr(nskyfiles)
mod_sky_list[*]=0
mod_full_list = intarr(nskyfiles+nobjfiles)
mod_full_list[*] = 0
stackedfile = [objfile,skyfile]

; get the calibration frames
hd=headfits(objfile[0])
exptime=sxpar(hd,'EXPTIME')
filter2=sxpar(hd,'AFT')
coadds=sxpar(hd,'COADDS')
print,filter2,exptime


; determine which flatfield to use
if (keyword_set(FLATFILE) NE 1) then begin
case 1 of
   (filter2 EQ 'Ks__(2.15)'):begin 
             flat=readfits('kflat.fits')
             print,'Kflat selected.'
             end
   (filter2 EQ 'H__(1.64)'):begin
             flat=readfits('hflat.fits')
             print,'Hflat selected.'
             end
   (filter2 EQ 'J__(1.25)'): begin
             flat=readfits('jflat.fits')
             print,'Jflat selected.'
             end
   else: begin
         flat=fltarr(2048,2048)
         flat[*,*]=1.
         print,'No flat selected.'
         end
   endcase
endif else begin
   flat=readfits(FLATFILE)
   endelse
 
 
 
; find the right dark calibration file
if (keyword_set(DARKFILE) NE 1) then begin 

; get the automatic dark files and test for existence
darkfile=strcompress('dark_'+string(floor(exptime))+'_'+string(coadds)+'.fits',/remove_all)
;print,darkfile
filetest=file_test(darkfile)
filetest2=file_test('darkmodel.fits')

if (filetest EQ 1) then begin
      dark=readfits(darkfile)
      print,'Reading ',darkfile
      endif
      
if ((filetest NE 1) and(filetest2 EQ 1)) then begin
      print,'Can not find matching exptime dark!'
      print,'Falling back to dark current model.'
      darkmodel=readfits('darkmodel.fits')  
      dark=darkmodel[*,*,0]+exptime*coadds*darkmodel[*,*,1] 
    endif
    
if ((filetest NE 1) and (filetest2 NE 1)) then begin
      print,' No dark info found!'
      print,' No dark will be used.'
      dark=fltarr(2048,2048)
      dark[*]=0
   endif
      
endif else begin
   dark=readfits(DARKFILE)
   print,'Using manually specified dark.'
   print,'Reading ',darkfile
   endelse

; make the running sky sub frame
for i=0,nobjfiles+nskyfiles-1 do begin


if i lt nobjfiles then begin ;Do the object frames
   doing_obj = 1
   doing_sky = 0
endif else begin ;Do the sky frames
   doing_sky = 1
   doing_obj = 0
endelse      

if doing_obj then begin
   mod_sky_list = intarr(skylen)
   mod_sky_list[*]=0
   chunk = i/3
   nn = objlen/3-1
   case chunk of
      0: mod_sky_list[0:2] = 1
      nn: mod_sky_list[skylen-3:skylen-1] = 1
      else: mod_sky_list[chunk*3-3:chunk*3+3-1] = 1
   endcase
   currfile = objfile[i]
endif else begin
   mod_full_list = intarr(skylen+objlen)
   mod_full_list[*] = 0
   kk = i-objlen
   chunk = kk/3+1
   jj = kk+chunk*3
   mod_full_list[jj-3:jj+3] = 1
   mod_full_list[jj] = 0
   mod_sky_list = mod_full_list
   ;Crude hack. Just declare these full lists
   ;as the sky lists. Works because we do 
   ;sky frames after all the object frames.
   nskyfiles = skylen+objlen
   skyfile = infile
   currfile = stackedfile[i]
endelse

print,'--------------'      
print,i,'    ',currfile
print,'--------------'  
print,skyfile[where(mod_sky_list EQ 1)]
      
;load the background images
numimages=n_elements(where(mod_sky_list EQ 1))
images=fltarr(2048,2048,numimages)
masks=fltarr(2048,2048,numimages)
masks[*,*,*]=0

count=0
for j=0,nskyfiles-1 do begin

    if (mod_sky_list[j] EQ 1) then begin
           images[*,*,count]=readfits(skyfile[j])
           filename=strcompress('mask_'+skyfile[j],/remove_all)
           if (RUN EQ 2) then begin
              objmask = convol(readfits(filename),kernel)
              bpmmask = readfits("../scripts/bpm.fits")
              mask = objmask or bpmmask
              masks[*,*,count]=mask
              endif
           count=count+1
           endif
           
endfor
print,currfile
; now read in the actual data
image2=readfits(currfile,hd)-dark
data_background=median(image2)


; condition the input sky stack a little by
;    first subtracting the dark, then resetting the medians
;    equal to that in the input data frame
for j=0,numimages-1 do begin
        images[*,*,j]=images[*,*,j]-dark
        images[*,*,j]=images[*,*,j]*(data_background/median(images[*,*,j]))
endfor

; zap the input images based on the masks
if (RUN EQ 2) then images(where(masks NE 0))=sqrt(-1)

; generate the output array
out=fltarr(2048,2048)
out[*]=0


; generate the median sky - note that median rejects all the nans
;for j=0,2047 do begin
;  for k=0,2047 do begin

;     out[j,k]=median(images[j,k,*])

; endfor
;endfor
out=median(images,DIMENSION=3)



; get the output file basename
if (strlowcase(strmid(currfile,2,3,/reverse)) EQ '.gz' ) then begin
       outbase=strmid(currfile,0,strlen(currfile)-3)
    endif else begin
       outbase=currfile
    endelse

; finally, write the output sky image
if keyword_set(SAVESKY) then begin
outname=strcompress('sky_'+outbase,/remove_all)
if keyword_set(COMPRESS) then begin
             writefits,outname,out,hd,/COMPRESS
         endif else begin
             writefits,outname,out,hd
         endelse
endif


; add the basic WCS
ra=sxpar(hd,'RA')   ; from the TCS
dec=sxpar(hd,'DEC')
get_coords,coords,instring=(ra+' '+dec),/quiet
sxaddpar,hd,'CRVAL1',coords[0]*15
sxaddpar,hd,'CRVAL2',coords[1]
sxaddpar,hd,'CRPIX1',1024.0
sxaddpar,hd,'CRPIX2',1024.0
sxaddpar,hd,'CROTA2',1.4 ; from Thompson 1.4
sxaddpar,hd,'CDELT1',(-0.2487/3600.) ; from Thompson
sxaddpar,hd,'CDELT2',(0.2487/3600.)
sxaddpar,hd,'CTYPE1','RA---TAN'
sxaddpar,hd,'CTYPE2','DEC--TAN'
sxdelpar,hd,'PC1_1'
sxdelpar,hd,'PC1_2'
sxdelpar,hd,'PC2_1'
sxdelpar,hd,'PC2_2'
sxdelpar,hd,'CD1_1'
sxdelpar,hd,'CD1_2'
sxdelpar,hd,'CD2_1'
sxdelpar,hd,'CD2_2'
sxdelpar,hd,'CCROT'
sxdelpar,hd,'CROTA1'

; write the background to the header
rawmed=median(image2)
sxaddpar,hd,'RAWMED',rawmed,' median value of raw image'


; now make the actual data image
out=(image2-out)/flat

; scrub it with the quadrant scrubber
out2=fltarr(2048,2048)
out2[*]=0
if (keyword_set(NOQUADCLEAN) NE 1) then begin
              print,'Cleaning quadrants.'
              wirc_cleanquadrants,out,out2
          endif else begin
              out2=out
          endelse

; and write the output
outname=strcompress('ff_'+outbase,/remove_all)
sxaddpar,hd,'WIRCTRAD',timeradius
sxaddpar,hd,'WIRCRUN',RUN
if keyword_set(COMPRESS) then begin
          writefits,outname,out2,hd,/COMPRESS
  endif else begin
          writefits,outname,out2,hd
  endelse


; if this were the mask generating run
if (RUN EQ 1) then begin    
    ; run sextractor
      badpix=where(finite(out2,/infinity),badpixcount)
         if badpixcount GT 0 then out2[badpix]=999999
      badpix=where(finite(out2,/nan),badpixcount)
         if badpixcount GT 0 then out2[badpix]=999999
      writefits,'sex_temp.fits',out2,hd
      print,'Running SExtractor'
      spawn,'/scisoft/bin/sex sex_temp.fits -c ../scripts/sex_files/preproc_mask.sex '
      mask=readfits('check.fits',mask_hd)



; do a little more processing
      mask(where(flat LE 0.6))=0
      maskpixels=where(mask GT 0)
      if (maskpixels[0] NE -1) then  mask(maskpixels)=1 
      sxaddpar,hd,'WIRCTRAD',timeradius
      sxaddpar,mask_hd,'WIRCMSK',1
      outname=strcompress('mask_'+outbase,/remove_all)
      if keyword_set(COMPRESS) then begin
            writefits,outname,mask,mask_hd,/COMPRESS
         endif else begin
            writefits,outname,mask,mask_hd
         endelse

endif


endfor

; print the total time
stop_time=systime(/seconds)
print,(stop_time-start_time)/60.,' minutes elapsed.'


end
