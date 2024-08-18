###This script generates summaries for DaySim Usual Work and School Locations
###Distributions of home-work/school distances and times by persontype are produced

print("Work/School Location Summary...Started")

prep_wrkschloc <- function(perdata,hhdata,pdaydata,dataname)
{
  perdata <- merge(perdata,hhdata,by="hhno",all.x=T)
  if (dataname=='daysim') perdata$wkathome <- pdaydata$wkathome[match(paste(perdata$hhno, perdata$pno, sep = "_"), paste(pdaydata$hhno, pdaydata$pno, sep="_"))]
  perdata[,wrkr:=ifelse(pwtyp>0 & pwtaz!=0,1,0)]
  perdata[,outhmwrkr:=ifelse(pwtaz>0 & hhparcel!=pwpcl,1,0)]
  perdata[,wrkrtyp:=c(1,2,3,3,3,3,3,3)[pptyp]]
  perdata[wrkr==1 & hhparcel==pwpcl,pwaudist:=0]
  perdata[wrkr==1 & hhparcel==pwpcl,pwautime:=0]
  perdata[,wrkdistcat:=findInterval(pwaudist,0:89)]
  perdata[,wrktimecat:=findInterval(pwautime,0:89)]
  perdata[pwtaz<0,wrkdistcat:=91]
  perdata[pwtaz<0,wrktimecat:=91]
  perdata[,stud:=ifelse(pptyp %in% c(5:7) & pstaz!=0,1,0)] 
  perdata[,outhmstud:=ifelse(pstaz>0 & hhparcel!=pspcl,1,0)]
  perdata[,stutyp:=c(4,4,4,4,3,2,1,4)[pptyp]]
  perdata[stud==1 & hhparcel==pspcl,psaudist:=0]
  perdata[stud==1 & hhparcel==pspcl,psautime:=0]
  perdata[,schdistcat:=findInterval(psaudist,0:89)]
  perdata[,schtimecat:=findInterval(psautime,0:89)]
  perdata[pstaz<0,schdistcat:=91]
  perdata[pstaz<0,schtimecat:=91]
  perdata[,hhdistrict:=countycorr$MOE_DIST[match(hhtaz,countycorr$TAZ)]]
  perdata[,pwdistrict:=countycorr$MOE_DIST[match(pwtaz,countycorr$TAZ)]]
  perdata[,psdistrict:=countycorr$MOE_DIST[match(pstaz,countycorr$TAZ)]]
  perdata[,hhcounty:=countycorr$DISTRICT[match(hhtaz,countycorr$TAZ)]]
  perdata[,pwcounty:=countycorr$DISTRICT[match(pwtaz,countycorr$TAZ)]]
  perdata[,pscounty:=countycorr$DISTRICT[match(pstaz,countycorr$TAZ)]]
  perdata[pwtaz<0,pwcounty:=21]  #assumes 20 counties
  perdata[pstaz<0,pscounty:=21]  #assumes 20 counties
  if (dataname=='daysim') perdata[,telc:=ifelse(wrkr==1 & wkathome>2.5,1,0)] #telecommute is wrk hours>2.5hrs
  perdata[,wfh:=ifelse(wrkr==1 & hhparcel==pwpcl,1,0)]
  perdata[,sfh:=ifelse(stud==1 & hhparcel==pspcl,1,0)]
  perdata[pwautime<0,pwautime:=NA]
  perdata[pwaudist<0,pwaudist:=NA]
  perdata[psautime<0,psautime:=NA]
  perdata[psaudist<0,psaudist:=NA]
  perdata[,wrkr_tlfd:=ifelse(wrkr==1 & wfh==0 & pwtaz>0,1,0)]
  perdata[,stud_tlfd:=ifelse(stud==1 & sfh==0 & pstaz>0,1,0)]
  
  return(perdata)
}

if(prepSurvey)
{
  survperdata <- assignLoad(paste0(surveyperfile,".Rdata"))
  survpdaydata <- assignLoad(paste0(surveypdayfile,".Rdata"))
  survhhdata <- assignLoad(paste0(surveyhhfile,".Rdata"))
  survperdata <- prep_wrkschloc(survperdata,survhhdata,survpdaydata,"survey")
  survperdata_wrk <- survperdata[pwpcl>0,]
  write_tables(wrklocmodelout,survperdata,wrklocmodelfile,"survey")
  survperdata_schl <- survperdata[pspcl>0,]
  write_tables(schlocmodelout,survperdata,schlocmodelfile,"survey")
  rm(survperdata,survhhdata)
  gc()
}

if(prepDaySim)
{
  dsperdata <- assignLoad(paste0(dsperfile,".Rdata"))
  dspdaydata <- assignLoad(paste0(dspdayfile,".Rdata"))
  dshhdata <- assignLoad(paste0(dshhfile,".Rdata"))
  dsperdata <- prep_wrkschloc(dsperdata,dshhdata,dspdaydata,"daysim")
  write_tables(wrklocmodelout,dsperdata,wrklocmodelfile,"daysim")
  write_tables(schlocmodelout,dsperdata,schlocmodelfile,"daysim")
  rm(dsperdata,dshhdata)
  gc()
}

print("Work/School Location Summary...Finished")
