setwd("~/vikparuchuri/doc-compare")

physician_medicare = "data/Medicare-Physician-and-Other-Supplier-PUF-CY2012.txt"
hospital_quality = "data/National_Downloadable_File.csv"
aco_quality = "data/Accountable_Care_Organization__ACO__Quality_Data.csv"
life_expectancy = "data/state_life.csv"

data_file = "hospital.RData"
zips_file = "zips.RData"

is_installed <- function(mypkg) is.element(mypkg, installed.packages()[,1])

load_or_install<-function(package_names)
{
  for(package_name in package_names)
  {
    if(!is_installed(package_name))
    {
      install.packages(package_name,repos="http://lib.stat.cmu.edu/R/CRAN")
    }
    options(java.parameters = "-Xmx8g")
    library(package_name,character.only=TRUE,quietly=TRUE,verbose=FALSE)
  }
}

rename_col <- function(old, new, frame){
  for(i in 1:length(old)){
    names(frame)[names(frame) == old[i]] = new[i]
  }
  frame
}

Mode <- function(x) {
  ux <- unique(x)r cumulative plot
  ux[which.max(tabulate(match(x, ux)))]
}

load_or_install(c("ffbase", "jsonlite", "data.table", "parallel", "bigmemory", "bigtabulate","ggplot2","stringr","foreach","wordcloud","lsa","MASS","openNLP","tm","fastmatch","reshape","openNLPmodels.en",'e1071','gridExtra', 'XLConnect', 'reshape', 'plyr', 'RColorBrewer', 'rjson'))

if(file.exists(data_file) && !exists("pm")){
  load(data_file)
  load(zips_file)
  pm = pm[2:nrow(pm),]
} else if(!file.exists(data_file)) {
  pm = read.delim(physician_medicare, stringsAsFactors=FALSE)
  
  hq = read.csv(hospital_quality, stringsAsFactors=FALSE)
  
  save(pm, hq, file=data_file)
}

life_e = read.csv(life_expectancy, stringsAsFactors=FALSE, na.strings = "-")

descriptor_vars = c("npi", "nppes_provider_last_org_name", "nppes_provider_first_name", "nppes_provider_mi", "nppes_credentials", "nppes_provider_gender", "nppes_entity_code", "nppes_provider_street1", "nppes_provider_street2", "nppes_provider_city", "nppes_provider_zip", "nppes_provider_state", "nppes_provider_country", "provider_type", "medicare_participation_indicator", "place_of_service")

hq_sel = unique(hq[,c("NPI", "Group.Practice.PAC.ID")])

pm$nppes_provider_zip = as.integer(pm$nppes_provider_zip)
pm$hcpcs_code = as.integer(pm$hcpcs_code)

sel_pm = pm[, c("npi", "hcpcs_code", "line_srvc_cnt", "bene_unique_cnt", "bene_day_srvc_cnt", "average_Medicare_allowed_amt", "stdev_Medicare_allowed_amt", "average_submitted_chrg_amt", "stdev_submitted_chrg_amt", "average_Medicare_payment_amt", "stdev_Medicare_payment_amt")]
sel_pm = data.table(sel_pm)
setkey(sel_pm, "npi") 

phys_summ = sel_pm[
  , 
  list(
    service_total=sum(line_srvc_cnt),
    ben_total=sum(bene_unique_cnt),
    payment=sum(average_Medicare_payment_amt * line_srvc_cnt),
    charged=sum(average_submitted_chrg_amt * line_srvc_cnt),
    allowed=sum(average_Medicare_allowed_amt * line_srvc_cnt),
    unique_services_per_patient=sum(bene_day_srvc_cnt)/sum(bene_unique_cnt),
    duplicates_per_service=sum(line_srvc_cnt)/sum(bene_day_srvc_cnt),
    services_per_patient=sum(line_srvc_cnt)/sum(bene_unique_cnt)
  ),
  by="npi"
  ]

hcpcs_summ = sel_pm[
  , 
  list(
    service_total=sum(line_srvc_cnt),
    ben_total=sum(bene_unique_cnt),
    payment=sum(average_Medicare_payment_amt * line_srvc_cnt),
    charged=sum(average_submitted_chrg_amt * line_srvc_cnt),
    allowed=sum(average_Medicare_allowed_amt * line_srvc_cnt)
  ),
  by="hcpcs_code"
  ]

hcpcs_summ$avg_payment = hcpcs_summ$payment/hcpcs_summ$service_total
hcpcs_summ = merge(hcpcs_summ, pm[,c("hcpcs_code", "hcpcs_description")], by="hcpcs_code")
hcpcs_summ = hcpcs_summ[!duplicated(hcpcs_summ$hcpcs_code),]
hcpcs_summ = hcpcs_summ[complete.cases(hcpcs_summ),]

tail(hcpcs_summ[order(hcpcs_summ$payment)], 10)
tail(hcpcs_summ[order(hcpcs_summ$avg_payment)], 10)

phys_summ$reimbursement_ratio = phys_summ$payment/phys_summ$charged

summary_vars = c("ben_total", "service_total", "payment", "charged", "allowed", "unique_services_per_patient", "duplicates_per_service", "services_per_patient")

phys_summ = merge(phys_summ, pm[,descriptor_vars], all.x=TRUE, all.y=FALSE, by="npi")
phys_summ = phys_summ[!duplicated(phys_summ$npi),]

docs = phys_summ[nppes_entity_code=="I"]
orgs = phys_summ[nppes_entity_code=="O"]

females = docs[nppes_provider_gender=="F",]
males = docs[nppes_provider_gender=="M",]

im = docs[provider_type=="Internal Medicine",]

cor(phys_summ[,summary_vars, with=FALSE])
cor(docs[,summary_vars, with=FALSE])
cor(orgs[,summary_vars, with=FALSE])

summary(docs[nppes_provider_gender=="F",summary_vars, with=FALSE])


summary(orgs[,summary_vars, with=FALSE])

vals = tapply(docs$payment, docs$nppes_provider_state, mean)


per_state_charges = data.frame(state=names(tapply(docs$payment, docs$nppes_provider_state, mean)), charge=tapply(docs$payment, docs$nppes_provider_state, mean))
life_comp = merge(life_e, per_state_charges, by.x="Code", by.y="state", all.y=FALSE, all.x=TRUE)

cor(life_comp[!is.na(life_comp[,"Native.American"]),c("Native.American", "charge")])
    
phys_ord = docs[order(docs$payment),c("npi", "payment"), with=FALSE]
phys_ord$pay_cumulative = cumsum(phys_ord$payment)
split_dist = floor(nrow(phys_ord)/20)
groups = as.numeric(lapply(1:20, function(x){
  phys_ord$pay_cumulative[split_dist * x]
}))
groups = (groups/groups[20]) * 100
plot_data = data.frame(x=1:20 * 5,y=groups)
write(toJSON(plot_data), file="chart_data/doctor_inequality.json")

common_occupations = names(tail(sort(table(docs$provider_type)),10))
occupations = do.call(rbind,lapply(common_occupations, function(x){
  data.frame(occupation=x, female_count=nrow(females[females$provider_type==x,]), male_count=nrow(males[males$provider_type==x,]))
}));
write(toJSON(occupations), file="chart_data/occupations.json")

occupation_pay = do.call(rbind,lapply(common_occupations, function(x){
  data.frame(occupation=x, female_count=mean(females$payment[females$provider_type==x]), male_count=mean(males$payment[males$provider_type==x]))
}));
write(toJSON(occupation_pay), file="chart_data/occupation_pay.json")

top_docs = docs[docs$payment > 1000000,]
top_docs$zip = as.numeric(lapply(top_docs$nppes_provider_zip, function(x) {
  val = as.character(x)
  as.numeric(substr(val, 1, 5))
}))

top_docs = merge(top_docs, zips, by="zip", all.x=TRUE, all.y=FALSE)
top_docs = top_docs[complete.cases(top_docs),]
top_docs$name = paste(top_docs$nppes_provider_first_name, top_docs$nppes_provider_last_org_name, top_docs$nppes_credentials)
sel_data = top_docs[,c("name", "payment", "lat", "long"), with=FALSE]
write(toJSON(sel_data), file="chart_data/top_docs.json")
