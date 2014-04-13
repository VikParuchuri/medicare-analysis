## Not needed
split_dat = lapply(un[1:100], function(x) subset(sel_pm, npi==x))

inds = split(seq_len(nrow(sel_pm)), sel_pm$npi)
phys_summ = lapply(inds, function(x) summ(sel_pm[x,]))

h_inds = split(seq_len(nrow(sel_pm)), sel_pm$hcpcs_code)
hcs_summ = lapply(h_inds, function(x) summ(sel_pm[x,]))

ssel_pm = bigsplit(sel_pm, sel_pm[,1])
sel_pm_hc = pm[, c("npi", "h", "line_srvc_cnt", "bene_unique_cnt", "bene_day_srvc_cnt", "average_Medicare_allowed_amt", "stdev_Medicare_allowed_amt", "average_submitted_chrg_amt", "stdev_submitted_chrg_amt", "average_Medicare_payment_amt", "stdev_Medicare_payment_amt")]


phys_summ = by(sel_pm, sel_pm$npi, summ)

phys_summ = ddply(
  sel_pm[1:1000,],
  .(npi),
  summarize,
  ben_total=sum(bene_day_srvc_cnt),
  payment=(ben_total * mean(average_Medicare_payment_amt)),
  charged=(ben_total * mean(average_submitted_chrg_amt)),
  allowed=(ben_total * mean(average_Medicare_allowed_amt))
)



phys_summ = ffdfdply(
  ffpm, 
  split=ffpm$key, 
  FUN = function(x) summ(x),
  BATCHBYTES = 5000,
)
ffiris <- as.ffdf(iris)
hs_summ = ddply(
  pm, 
  .(npi), 
  summarize, 
  ben_total=sum(bene_day_srvc_cnt),
  payment=(ben_total * mean(average_Medicare_payment_amt)), 
  charged=(ben_total * mean(average_submitted_chrg_amt)), 
  allowed=(ben_total * mean(average_Medicare_allowed_amt)),
  bad_charge_r=charged/allowed,
  service_r=sum(bene_day_srvc_cnt)/sum(bene_unique_cnt),
  credentials=nppes_credentials[1],
  gender=nppes_provider_gender[1],
  entity_code=nppes_entity_code[1],
  state=nppes_provider_state[1],
  type=provider_type[1],
  street1=nppes_provider_street1[1],
  street2=nppes_provider_street2[1],
  zip=nppes_provider_zip[1],
  city=nppes_provider_city[1]
)

summ = function(x){
  service_total=sum(x$bene_day_srvc_cnt)
  ben_total=sum(x$bene_unique_cnt)
  payment=(ben_total * mean(x$average_Medicare_payment_amt))
  charged=(ben_total * mean(x$average_submitted_chrg_amt))
  allowed=(ben_total * mean(x$average_Medicare_allowed_amt))
  bad_charge_r=charged/allowed
  service_r=sum(x$bene_day_srvc_cnt)/sum(x$bene_unique_cnt)
  list(ben_total, payment, charged, allowed, bad_charge_r, service_r)
}
