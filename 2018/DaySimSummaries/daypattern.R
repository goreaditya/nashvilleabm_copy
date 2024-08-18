###This script generates Day Patterns from DaySim run outputs

print("Day Pattern Summary...Started")

prep_perdata <- function(perdata,hhdata)
{
  hhdata[,hhcounty:=countycorr$DISTRICT[match(hhtaz,countycorr$TAZ)]]
  hhdata[,inccat:=findInterval(hhincome,c(0,15000,50000,75000))]
  perdata[,hh16cat:=ifelse(pagey>=16,1,0)]
  hhdata <- merge(hhdata,perdata[,list(hh16cat=sum(hh16cat)),by=hhno],by="hhno",all.x=T)
  hhdata[hh16cat>4,hh16cat:=4]
  hhdata[hhvehs == 0,vehsuf:=1]
  hhdata[hhvehs > 0 & hhvehs < hh16cat,vehsuf:=2]
  hhdata[hhvehs > 0 & hhvehs == hh16cat,vehsuf:=3]
  hhdata[hhvehs > 0 & hhvehs > hh16cat,vehsuf:=4]
  perdata <- merge(perdata,hhdata[,list(hhno,hhcounty,inccat,vehsuf)],by="hhno",all.x=T)
  return(perdata)
}

prep_survey_pdayadata <-function(pdaydata)
{
	#to make survey consistent with present DaySim output of stops field - 03/04/2022
	#in future, need to update DaySim to output actuall number of stops instead of 0 or 1.
	#when that happens, remove this function.
	pdaydata[wkstops>0,wkstops:=1]
	pdaydata[scstops>0,scstops:=1]
	pdaydata[esstops>0,esstops:=1]
	pdaydata[pbstops>0,pbstops:=1]
	pdaydata[shstops>0,shstops:=1]
	pdaydata[wkstops>0,wkstops:=1]
	pdaydata[mlstops>0,mlstops:=1]
	pdaydata[sostops>0,sostops:=1]
	return(pdaydata)

}

prep_pdaydata <- function(pdaydata,perdata)
{

  pdaydata <- merge(pdaydata,perdata,by=c("hhno","pno"),all.x=T)
  if(excludeChildren5)
    pdaydata <- pdaydata[pptyp<8]
  
  #added to set worktours=0 for workers working outside county - should affect only the survey
  #NOTE: enable only region specific data  
  #pdaydata[,wrkr:=ifelse(pwtyp>0 & pwtaz!=0,1,0)]
  #pdaydata[,wktours:=ifelse(pwtaz<0 & wrkr==1,0,wktours)]
  
  pdaydata[,pbtours:= pbtours + metours]
  pdaydata[,sotours:= sotours + retours]
  pdaydata[,pbstops:= pbstops + mestops]
  pdaydata[,sostops:= sostops + restops]
  
  pdaydata[,tottours:=wktours+sctours+estours+pbtours+shtours+mltours+sotours]
  pdaydata[tottours>3,tottours:=3]
  pdaydata[,totstops:=wkstops+scstops+esstops+pbstops+shstops+mlstops+sostops]

  pdaydata[tottours == 0 & totstops == 0,tourstop:=0]
  pdaydata[tottours == 1 & totstops == 0,tourstop:=1]
  pdaydata[tottours == 1 & totstops == 1,tourstop:=2]
  pdaydata[tottours == 1 & totstops == 2,tourstop:=3]
  pdaydata[tottours == 1 & totstops >= 3,tourstop:=4]
  pdaydata[tottours == 2 & totstops == 0,tourstop:=5]
  pdaydata[tottours == 2 & totstops == 1,tourstop:=6]
  pdaydata[tottours == 2 & totstops == 2,tourstop:=7]
  pdaydata[tottours == 2 & totstops >= 3,tourstop:=8]
  pdaydata[tottours == 3 & totstops == 0,tourstop:=9]
  pdaydata[tottours == 3 & totstops == 1,tourstop:=10]
  pdaydata[tottours == 3 & totstops == 2,tourstop:=11]
  pdaydata[tottours == 3 & totstops >= 3,tourstop:=12]
  
  pdaydata[wktours == 0 & wkstops == 0,wktostp:=1]
  pdaydata[wktours == 0 & wkstops >= 1,wktostp:=2]
  pdaydata[wktours >= 1 & wkstops == 0,wktostp:=3]
  pdaydata[wktours >= 1 & wkstops >= 1,wktostp:=4]
  
  pdaydata[sctours == 0 & scstops == 0,sctostp:=1]
  pdaydata[sctours == 0 & scstops >= 1,sctostp:=2]
  pdaydata[sctours >= 1 & scstops == 0,sctostp:=3]
  pdaydata[sctours >= 1 & scstops >= 1,sctostp:=4]
  
  pdaydata[estours == 0 & esstops == 0,estostp:=1]
  pdaydata[estours == 0 & esstops >= 1,estostp:=2]
  pdaydata[estours >= 1 & esstops == 0,estostp:=3]
  pdaydata[estours >= 1 & esstops >= 1,estostp:=4]
  
  pdaydata[pbtours == 0 & pbstops == 0,pbtostp:=1]
  pdaydata[pbtours == 0 & pbstops >= 1,pbtostp:=2]
  pdaydata[pbtours >= 1 & pbstops == 0,pbtostp:=3]
  pdaydata[pbtours >= 1 & pbstops >= 1,pbtostp:=4]
  
  pdaydata[shtours == 0 & shstops == 0,shtostp:=1]
  pdaydata[shtours == 0 & shstops >= 1,shtostp:=2]
  pdaydata[shtours >= 1 & shstops == 0,shtostp:=3]
  pdaydata[shtours >= 1 & shstops >= 1,shtostp:=4]
  
  pdaydata[mltours == 0 & mlstops == 0,mltostp:=1]
  pdaydata[mltours == 0 & mlstops >= 1,mltostp:=2]
  pdaydata[mltours >= 1 & mlstops == 0,mltostp:=3]
  pdaydata[mltours >= 1 & mlstops >= 1,mltostp:=4]
  
  pdaydata[sotours == 0 & sostops == 0,sotostp:=1]
  pdaydata[sotours == 0 & sostops >= 1,sotostp:=2]
  pdaydata[sotours >= 1 & sostops == 0,sotostp:=3]
  pdaydata[sotours >= 1 & sostops >= 1,sotostp:=4]

  pdaydata[,wktopt:=findInterval(wktours,0:3)]
  pdaydata[,sctopt:=findInterval(sctours,0:3)]
  pdaydata[,estopt:=findInterval(estours,0:3)]
  pdaydata[,pbtopt:=findInterval(pbtours,0:3)]
  pdaydata[,shtopt:=findInterval(shtours,0:3)]
  pdaydata[,mltopt:=findInterval(mltours,0:3)]
  pdaydata[,sotopt:=findInterval(sotours,0:3)]
  
  #tours>0 and stops>0
  pdaydata[,wktostpcombo:=0] #default is 0
  pdaydata[wktours >= 1 & wkstops >= 1,wktostpcombo:=1] #work tour
  pdaydata[wktours >= 1 & scstops >= 1,wktostpcombo:=2] #work tour 
  pdaydata[wktours >= 1 & esstops >= 1,wktostpcombo:=3] #work tour
  pdaydata[wktours >= 1 & pbstops >= 1,wktostpcombo:=4] #work tour
  pdaydata[wktours >= 1 & shstops >= 1,wktostpcombo:=5] #work tour
  pdaydata[wktours >= 1 & mlstops >= 1,wktostpcombo:=6] #work tour
  pdaydata[wktours >= 1 & sostops >= 1,wktostpcombo:=7] #work tour  
  
  pdaydata[,sctostpcombo:=0] #default is 0
  pdaydata[sctours >= 1 & wkstops >= 1,sctostpcombo:=1] #school tour
  pdaydata[sctours >= 1 & scstops >= 1,sctostpcombo:=2] #school tour 
  pdaydata[sctours >= 1 & esstops >= 1,sctostpcombo:=3] #school tour
  pdaydata[sctours >= 1 & pbstops >= 1,sctostpcombo:=4] #school tour
  pdaydata[sctours >= 1 & shstops >= 1,sctostpcombo:=5] #school tour
  pdaydata[sctours >= 1 & mlstops >= 1,sctostpcombo:=6] #school tour
  pdaydata[sctours >= 1 & sostops >= 1,sctostpcombo:=7] #school tour  

  pdaydata[,estostpcombo:=0] #default is 0
  pdaydata[estours >= 1 & wkstops >= 1,estostpcombo:=1] #escort tour
  pdaydata[estours >= 1 & scstops >= 1,estostpcombo:=2] #escort tour 
  pdaydata[estours >= 1 & esstops >= 1,estostpcombo:=3] #escort tour
  pdaydata[estours >= 1 & pbstops >= 1,estostpcombo:=4] #escort tour
  pdaydata[estours >= 1 & shstops >= 1,estostpcombo:=5] #escort tour
  pdaydata[estours >= 1 & mlstops >= 1,estostpcombo:=6] #escort tour
  pdaydata[estours >= 1 & sostops >= 1,estostpcombo:=7] #escort tour 

  pdaydata[,pbtostpcombo:=0] #default is 0  
  pdaydata[pbtours >= 1 & wkstops >= 1,pbtostpcombo:=1] #pers bus tour
  pdaydata[pbtours >= 1 & scstops >= 1,pbtostpcombo:=2] #pers bus tour 
  pdaydata[pbtours >= 1 & esstops >= 1,pbtostpcombo:=3] #pers bus tour
  pdaydata[pbtours >= 1 & pbstops >= 1,pbtostpcombo:=4] #pers bus tour
  pdaydata[pbtours >= 1 & shstops >= 1,pbtostpcombo:=5] #pers bus tour
  pdaydata[pbtours >= 1 & mlstops >= 1,pbtostpcombo:=6] #pers bus tour
  pdaydata[pbtours >= 1 & sostops >= 1,pbtostpcombo:=7] #pers bus tour  

  pdaydata[,shtostpcombo:=0] #default is 0
  pdaydata[shtours >= 1 & wkstops >= 1,shtostpcombo:=1] #shop tour
  pdaydata[shtours >= 1 & scstops >= 1,shtostpcombo:=2] #shop tour 
  pdaydata[shtours >= 1 & esstops >= 1,shtostpcombo:=3] #shop tour
  pdaydata[shtours >= 1 & pbstops >= 1,shtostpcombo:=4] #shop tour
  pdaydata[shtours >= 1 & shstops >= 1,shtostpcombo:=5] #shop tour
  pdaydata[shtours >= 1 & mlstops >= 1,shtostpcombo:=6] #shop tour
  pdaydata[shtours >= 1 & sostops >= 1,shtostpcombo:=7] #shop tour  

  pdaydata[,mltostpcombo:=0] #default is 0
  pdaydata[mltours >= 1 & wkstops >= 1,mltostpcombo:=1] #meal tour
  pdaydata[mltours >= 1 & scstops >= 1,mltostpcombo:=2] #meal tour 
  pdaydata[mltours >= 1 & esstops >= 1,mltostpcombo:=3] #meal tour
  pdaydata[mltours >= 1 & pbstops >= 1,mltostpcombo:=4] #meal tour
  pdaydata[mltours >= 1 & shstops >= 1,mltostpcombo:=5] #meal tour
  pdaydata[mltours >= 1 & mlstops >= 1,mltostpcombo:=6] #meal tour
  pdaydata[mltours >= 1 & sostops >= 1,mltostpcombo:=7] #meal tour  

  pdaydata[,sotostpcombo:=0] #default is 0
  pdaydata[sotours >= 1 & wkstops >= 1,sotostpcombo:=1] #socrec tour
  pdaydata[sotours >= 1 & scstops >= 1,sotostpcombo:=2] #socrec tour 
  pdaydata[sotours >= 1 & esstops >= 1,sotostpcombo:=3] #socrec tour
  pdaydata[sotours >= 1 & pbstops >= 1,sotostpcombo:=4] #socrec tour
  pdaydata[sotours >= 1 & shstops >= 1,sotostpcombo:=5] #socrec tour
  pdaydata[sotours >= 1 & mlstops >= 1,sotostpcombo:=6] #socrec tour
  pdaydata[sotours >= 1 & sostops >= 1,sotostpcombo:=7] #socrec tour  
  
  return(pdaydata)
}

prep_tourdata <- function(tourdata,perdata)
{
  tourdata <- merge(tourdata,perdata,by=c("hhno","pno"),all.x=T)
  if(excludeChildren5)
    tourdata <- tourdata[pptyp<8,]

  tourdata[pdpurp==8,pdpurp:=7]
  tourdata[pdpurp==9,pdpurp:=4]
  tourdata[,ftwind:=ifelse(pptyp==1,1,2)]

  tourdata[,stcat:=findInterval(subtrs,0:3)]
  tourdata[,stops:=tripsh1+tripsh2-2]
  tourdata[,stopscat:=findInterval(stops,1:6)]
  tourdata[,h1stopscat:=findInterval(tripsh1-1,1:6)]
  tourdata[,h2stopscat:=findInterval(tripsh2-1,1:6)]
  tourdata[,pdpurp2:=ifelse(parent == 0,pdpurp,8)]
  
  #added to set pdpurp2=0 for workers working outside county - should affect only the survey
  #NOTE: enable only region specific data  
  #tourdata[,wrkr:=ifelse(pwtyp>0 & pwtaz!=0,1,0)]
  #tourdata[,pdpurp2:=ifelse(pwtaz<0 & wrkr==1 & pdpurp2==1,0,pdpurp2)]  

  return(tourdata)
}

prep_tripdata <- function(tripdata,perdata)
{
  tripdata <- merge(tripdata,perdata,by=c("hhno","pno"),all.x=T)
  if(excludeChildren5)
    tripdata <- tripdata[pptyp<8]
  
  tripdata[dpurp==8,dpurp:=7]
  tripdata[dpurp==9,dpurp:=4]
  tripdata[dpurp==0,dpurp:=8]
  
  tripdata[,ocounty:=countycorr$DISTRICT[match(otaz,countycorr$TAZ)]]

  return(tripdata)
}

if(prepSurvey)
{
  survperdata <- assignLoad(paste0(surveyperfile,".Rdata"))
  survhhdata <- assignLoad(paste0(surveyhhfile,".Rdata"))
  survperdata <- prep_perdata(survperdata,survhhdata)
  survperdata <- survperdata[,c("hhno","pno","pptyp","pwtyp","pwtaz","pwpcl","hhcounty","inccat","vehsuf","psexpfac"),with=F]
  if(tourAdj)
  {
    setnames(touradj,2,"adjfac")
    survperdata <- merge(survperdata,touradj,by=c("pptyp"),all.x=T)
    survperdata[is.na(adjfac),adjfac:=1]
    survperdata[,psexpfac_orig:=psexpfac]
    survperdata[,psexpfac:=psexpfac*adjfac]
  }
  
  
  survpdaydata <- assignLoad(paste0(surveypdayfile,".Rdata"))
  #survpdaydata <- prep_survey_pdayadata(survpdaydata)
  survpdaydata <- prep_pdaydata(survpdaydata,survperdata)
  write_tables(daypatmodelout,survpdaydata,daypatmodelfile1,"survey")
  rm(survpdaydata)
  rm(survhhdata)
  
  survtourdata <- assignLoad(paste0(surveytourfile,".Rdata"))
  survtourdata <- prep_tourdata(survtourdata,survperdata)
  write_tables(daypatmodelout,survtourdata,daypatmodelfile2,"survey")
  rm(survtourdata)
  
  survtripdata <- assignLoad(paste0(surveytripfile,".Rdata"))
  survtripdata <- prep_tripdata(survtripdata,survperdata)
  write_tables(daypatmodelout,survtripdata,daypatmodelfile3,"survey")
  rm(survperdata,survtripdata)
  gc()
}

if(prepDaySim)
{
  dsperdata <- assignLoad(paste0(dsperfile,".Rdata"))
  dshhdata <- assignLoad(paste0(dshhfile,".Rdata"))
  dsperdata <- prep_perdata(dsperdata,dshhdata)
  dsperdata <- dsperdata[,c("hhno","pno","pptyp","pwtyp","pwtaz","pwpcl","hhcounty","inccat","vehsuf","psexpfac"),with=F]
  
  
  dspdaydata <- assignLoad(paste0(dspdayfile,".Rdata"))
  dspdaydata <- prep_pdaydata(dspdaydata,dsperdata)
  write_tables(daypatmodelout,dspdaydata,daypatmodelfile1,"daysim")
  rm(dspdaydata)
  rm(dshhdata)

  dstourdata <- assignLoad(paste0(dstourfile,".Rdata"))
  dstourdata <- prep_tourdata(dstourdata,dsperdata)
  write_tables(daypatmodelout,dstourdata,daypatmodelfile2,"daysim")
  rm(dstourdata)
  
  dstripdata <- assignLoad(paste0(dstripfile,".Rdata"))
  dstripdata <- prep_tripdata(dstripdata,dsperdata)
  write_tables(daypatmodelout,dstripdata,daypatmodelfile3,"daysim")
  rm(dsperdata,dstripdata)
  
  gc()
}

print("Day Pattern Summary...Finished")






