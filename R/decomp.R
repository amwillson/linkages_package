##' @title LINKAGES decomp function
##' @author Ann Raiho
##'
##' @param fdat current year
##' @param aet average temperature by month for current year
##' @param ncohrt average precipitation by month for current year
##' @param fc field capacity
##' @param dry wilting point
##' @param tyl total yearly litter
##' @param C.mat carbon matrix
##'
##' @description DECOMP CALCULATES CARBON AND NITROGEN FLOWS THROUGH
##'    SOIL. AVAILABLE N (AVAILN) IS USED IN GMULT TO CALCULATE
##'    SOIL NITROGEN GROWTH MULTIPLIERS. AET IS FED IN FROM MOIST.
##'    THIS YEAR'S LEAF, TWIG, ROOT, AND WOOD LITTER IS FED IN FROM KILL
##'    (ARRAY TYL). THE SIMULATION STARTS ON BARE GROUND (ONLY HUMUS
##'    PRESENT. BASESC AND BASESN ARE STARTING HUMUS WEIGHT AND N
##'    CONTENTS READ IN INPUT). THREE TYPES OF SOIL ORGANIC MATTER ARE
##'    RECOGNIZED: COHORTS EITHER IMMOBILIZING OR RAPIDLY MINERALIZING
##'    NITROGEN AND A HOMOGENOUS HUMUS POOL SLOWLY MINERALIZING N.
##'
##' @return ff weights and n content of forest floor by litter type
##' @return availn available N
##' @return tyln leaf litter N content
##' @return hcn humus C:N ratio
##' @return sco2 total soil co2-c
##' @return ncohrt number of cohorts
##' @return C.mat matrix for data on litter cohorts
##' @export
##'
decomp <- function(fdat, aet, ncohrt,fc,dry, tyl = rep(0,17), C.mat){
  #Initialization

  fco2 = 0 #co2-c from litter immobilizing N
  hco2 = 0 #co2-c from humus
  sco2 = 0 #total soil co2-c
  ffw = 0 #new well decayed wood cohort
  tnimob = 0 #total N immobilization
  availn = 0 #available N
  fnmin = 0
  hnmin = 0
  tnmin = 0 #total N mineralization
  tyln = 0 #leaf litter N content
  ff = matrix(0,20,3) #weights and n content of forest floor by litter type

  #Calculate Litter N
  tyln = sum(tyl[1:12]*fdat[1:12,2])


  #Calculate AET Multiplier
  xaet = aet
  if(xaet > 600) xaet = 600
  aetm = (-1 * xaet) / (-1200 + xaet)

  #Create new cohorts
  #the first row of the c array holds data on  humus
  #row 2 through ncohrt hold data on litter cohrts
  #C.mat[,1] weight in (t/ha)
  #C.mat[,2] N content (t/ha)
  #C.mat[,3:4] n change parameters
  #C.mat[,5] litter type, 1-12 are leaves, 13 is root, 14 and 15 are wood, 16 is twigs
  #17 is well-decayed wood, and 18 is humus
  #C.mat[,6] destination when transferred, 1=humus, 2=well-decayed wood
  #C.mat[,7] current %lignin
  #C.mat[,8:9] lignin decay parameters
  #C.mat[,10] original weight
  #C.mat[,11] current %N
  #C.mat[,12] fraction of original weight which will become humus or well decayed wood.
  #when this fraction is reached the cohort is transferred to the destination specified
  #by C.mat[,6]. This fraction is based on the lignin content of leaves.
  for(i in 1:16){
    if(tyl[i]==0) next
    ncohrt = ncohrt + 1
    if(ncohrt>100) print("ncohrt error")
    C.mat[ncohrt,1] = tyl[i] * fdat[i,10]
    C.mat[ncohrt,2] = tyl[i] * fdat[i,2]

    C.mat[ncohrt,3:9] = as.matrix(fdat[i,3:9])
    C.mat[ncohrt,10] = as.matrix(tyl[i] * fdat[i,10])
    C.mat[ncohrt,11] = fdat[i,2]
    C.mat[ncohrt,12] = fdat[i,7] * 1.7039 + .0955
    if(C.mat[ncohrt,5]==14) C.mat[ncohrt,12]=.3
    if(C.mat[ncohrt,5]==15) C.mat[ncohrt,12]=.3
    if(C.mat[ncohrt,5]==16) C.mat[ncohrt,12]=.3
  }

  #calculate decay multiplier, simulating effect of gaps on decay
  tyll = tyl[17]
  ccll = 1.54 + .0457 * (fc - dry) #ccll = 1?
  if(tyll > ccll) tyll = ccll
  decmlt = 1 + (-.5+.075*(fc-dry))*(1-tyll/ccll)

  if(ncohrt!=1){ #bypass forest floor cohort calculations if there is no floor
    #loop to calculate litter decay, N immobilization, lignin decay, and litter co2 evolution
    for(i in 2:ncohrt){
      #calculate % wt loss based on aet and lignin:N ratio
      pwtlos = (.9804+.09352*aet)-((-.4956+.00193*aet)*(C.mat[i,7]/C.mat[i,11]))
      pwtlos = (decmlt*pwtlos)/100
      if(pwtlos > .99) pwtlos = .99

      lt = C.mat[i,5]
      if(lt==14) pwtlos = .1
      if(lt==15) pwtlos = .03
      if(lt==17) pwtlos = .05
      if(lt==16 & pwtlos>.2) pwtlos = .2

      #calculate actual wt loss (t/ha)
      wtloss = pwtlos*C.mat[i,1]
      #calculate fraction of organic matter remaining
      pomr = (C.mat[i,1]-wtloss)/C.mat[i,10]
      #find new N concentration in cohort
      C.mat[i,11] = C.mat[i,3] - C.mat[i,4] * pomr
      #retain cohort for another year of decay if fraction remaining is greater
      #than fraction which will become humus of well decayed wood
      if(pomr<=C.mat[i,12]){
        #if cohrt is to be transferred to humus, recalculate wtloss and N concentration
        #so that the transfer occurs at the fraction specified by the initial lignin concentration
        wtloss = C.mat[i,1] - C.mat[i,12] * C.mat[i,10]
        if(wtloss<0) wtloss = 0
        C.mat[i,11] = C.mat[i,3] - C.mat[i,4]*C.mat[i,12]
        #calculate absolute change in N content
        deltan = C.mat[i,2] - C.mat[i,11] * (C.mat[i,1] - wtloss)
        if(deltan<0) tnimob = tnimob - deltan
        if(deltan>=0) fnmin = fnmin + deltan
        #transfer cohorts
        if(C.mat[i,6]==1){
          C.mat[1,1] = C.mat[1,1] + C.mat[i,1] - wtloss
          C.mat[1,2] = C.mat[1,2] + C.mat[i,11] * (C.mat[i,1] - wtloss)
          C.mat[i,1] = 0
        }else{
          #FFW - temporary variable assigned to well decayed wood cohort
          ffw = ffw + C.mat[i,1] - wtloss
          C.mat[i,1] = 0
        }
      }
      #update cohorts
      if(C.mat[i,1]!=0){
        C.mat[i,1] = C.mat[i,1] - wtloss
        C.mat[i,2] = C.mat[i,1] * C.mat[i,11]
        C.mat[i,7] = C.mat[i,8] - C.mat[i,9] * (C.mat[i,1]/C.mat[i,10])
      }else{
        #calculate litter cohort co2 evolution
        fco2 = fco2 + (wtloss*.48)
      }
    }
    #throughfall is 16% of leaf litter N
    tnimob = tnimob - .16 * tyln
  }
  #calculate humus N mineralization
  hnmin = C.mat[1,2] * .035 * decmlt * aetm
  #subtract mineralized N from humus N pool and calculate humus co2
  hnnew = C.mat[1,2] - hnmin
  homnew = C.mat[1,1] * (hnnew/C.mat[1,2])
  hco2 = (C.mat[1,1] - homnew) * .48
  C.mat[1,1] = homnew
  C.mat[1,2] = hnnew
  #hcn - humus C:N ratio
  hcn = (.48*C.mat[1,1])/C.mat[1,2]
  #add humus N mineralization to cohort N mineralization to get total N mineralization
  tnmin = fnmin + hnmin
  #subtract immobilization from total mineralization to get available N to trees
  availn = tnmin - tnimob
  #calculate total soil respiration
  sco2 = fco2+hco2
  if(sco2<0) browser()

  # remove transferred cohorts
  ix = 0
  for(i in 1:ncohrt){
    if(C.mat[i,1] == 0){
      # Remove row if there's no C remaining
      C.mat = C.mat[-i,]
      # Replace the row with an empty one to maintain the same number of rows
      C.mat = rbind(C.mat, rep(0, times = 15))
      # Increment counter
      ix = ix + 1
    }
  }

  # adjust number of cohorts
  ncohrt = ncohrt - ix

  #create new well decayed wood cohort
  if(ffw != 0 ){
    ncohrt = ncohrt + 1
    if(ncohrt>100) print("too many ncohrt")
    C.mat[ncohrt,1] = ffw
    C.mat[ncohrt,2] = ffw * fdat[17,2]

    C.mat[ncohrt,3:9] = unlist(fdat[17,3:9])

    C.mat[ncohrt,10] = ffw
    C.mat[ncohrt,11] = fdat[17,2]
    C.mat[ncohrt,12] = .5
  }
  #calculate total wt and N content by forest floor compartment
  for(i in 1:ncohrt){
    lt = C.mat[i,5]
    ff[lt,1] = C.mat[i,5]
    ff[lt,2] = ff[lt,2] + C.mat[i,1]
    ff[lt,3] = ff[lt,3] + C.mat[i,2]
  }
  ff[19,1] = 19
  for(lt in 1:12){
    ff[19,2] = ff[19,2] + ff[lt,2]
    ff[19,3] = ff[19,3] + ff[lt,3]
  }

  ff[19,2] = ff[19,2] + ff[18,2] + ff[13,2]
  ff[19,3] = ff[19,3] + ff[18,3] + ff[13,3]

  return(list(ff=ff, availn=availn, tyln = tyln, hcn=hcn, sco2=sco2, ncohrt=ncohrt,
              C.mat=C.mat))
}








