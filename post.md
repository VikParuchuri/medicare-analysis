<link rel="stylesheet" type="text/css" href="chart_data/nv.d3.css">
<link rel="stylesheet" type="text/css" href="chart_data/MarkerCluster.css">
<link rel="stylesheet" type="text/css" href="chart_data/MarkerCluster.Default.css">
<link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.css" />

<style>
  #top-physicians{
    height: 500px;
  }
</style>

<script src="http://d3js.org/d3.v3.js"></script>
<script src="http://cdnjs.cloudflare.com/ajax/libs/nvd3/1.1.15-beta/nv.d3.min.js"></script>
<script src="http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.js"></script>
<script src="chart_data/leaflet.markercluster.js"></script>


Exploring US healthcare data
========================================================

A few days ago, the Centers for Medicare and Medicaid Services [released](http://blog.cms.gov/2014/04/09/historic-release-of-data-delivers-unprecedented-transparency-on-the-medical-services-physicians-provide-and-how-much-they-are-paid/) some unprecedented data on the US healthcare system.  The data consists of 9 million rows showing how much each doctor in the US charged medicare, for what, and how much medicare paid out.  It doesn't quite cover everything (for example, services with less than 11 beneficiaries were removed for privacy reasons), but its the best thing we've got.

Immediately after the release, we started seeing [news stories](http://www.bloomberg.com/news/2014-04-09/top-medicare-doctor-paid-21-million-in-2012-data-shows.html) about how some doctors were making millions of dollars.  This information is easily found, and easily sensationalized, but I started to wonder what less obvious things might be in the data.

Getting the data
------------------------------------------------------------

You can grab the data [here](http://www.cms.gov/Research-Statistics-Data-and-Systems/Statistics-Trends-and-Reports/Medicare-Provider-Charge-Data/Physician-and-Other-Supplier.html).  I decided to use R to analyze it, because of the ease of interactive exploration and making visualizations.

Actually working with the data can be a bit tricky, depending on how much RAM you have.  I have a good amount, and for convenience just read the whole csv file in with `read.csv`.  You could always use something like the `ff` package or read the data straight into a database if you have memory limitations.

```
pm = read.delim(physician_medicare, stringsAsFactors=FALSE)
```

Great, now that we have our data, let's explore it.

Surface level explorations
------------------------------------------------------------

It's good to explore this kind of dataset rather than starting with specific questions to answer.  

Here is a truncated view of the data:

```
         npi hcpcs_code line_srvc_cnt average_Medicare_payment_amt
2 1003000126      99222           115                    108.11565
3 1003000126      99223            93                    158.87000
4 1003000126      99231           111                     30.72072
5 1003000126      99232           544                     56.65566
6 1003000126      99233            75                     81.39000
7 1003000126      99238            95                     55.76884
```

The important columns are `npi`, which is a unique ID for the physician, and `hcpcs_code`, which is a unique ID for the service the doctor performed.  The other two fields will be important down the line.  `line_srvc_count` is how many of the given service the doctor performed, and `average_Medicare_payment_amt` is how much medicare paid each time it was performed.  You should look at the [data documentation](https://www.cms.gov/Research-Statistics-Data-and-Systems/Statistics-Trends-and-Reports/Medicare-Provider-Charge-Data/Downloads/Medicare-Physician-and-Other-Supplier-PUF-Methodology.pdf) for what the other fields that aren't shown are.

Right now, the data is unique when `npi` and `hcpcs_code` are taken together.  So we have a summary of each service that each doctor performed.

We need to turn this into something that is unique on `npi` -- something that is a summary of what each doctor did.  This will make comparison and finding useful things much simpler.

Converting the data
----------------------------------------------------------------

To convert the data, we could use something like [ddply](http://cran.r-project.org/web/packages/plyr/index.html) or the base function `by`.  The problem with these is that they will be very slow for 9 million rows.  Even solutions like `ff` or `bigmemory` won't help much.  We could read the data into a database and then do a `group by` query to get data in batches, but we already picked the lazy route of reading into memory.

Fortunately, the [data table](http://cran.r-project.org/web/packages/data.table/index.html) package for R is awesome, and will make what we are doing easy.

```
pm = data.table(pm)
phys_summ = pm[
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
```

The above code will transform our data so that `npi` is unique.  It will calculate some descriptor variables (feel free to add your own) while it does it.  In this case, we will see how much each doctor charged medicare, how much they were paid, how many beneficiaries they served, and more.

Finally, some graphs!
-------------------------------------------------------------

Media reports focused on how much the top doctors made, and inequality in general is an interesting approach to this data.  Let's look at income inequality among doctors by finding what percentage of the income is made by what percentage of doctors (ie top 5% makes 50% of the income).

### Inequality across all physicians

To do this, we need to first just extract the data for doctors, and then calculate the cumulative sum of doctor payments.

I was actually simplifying things before when I said that the data showed how much each doctor charged medicare.  The data actually has information from organizations (labs, hospitals, etc), as well as doctors.  We can filter each one like this:

```
docs = phys_summ[nppes_entity_code=="I"]
orgs = phys_summ[nppes_entity_code=="O"]
```

`nppes_entity_code` indicates whether an individual or organization made the charges.  We can now calculate our cumulative payments:

```
phys_ord = docs[order(docs$payment),c("npi", "payment"), with=FALSE]
phys_ord$pay_cumulative = cumsum(phys_ord$payment)
split_dist = floor(nrow(phys_ord)/20)
groups = as.numeric(lapply(1:20, function(x){
  phys_ord$pay_cumulative[split_dist * x]
}))
groups = (groups/groups[20]) * 100
```

The above code will give us how much the first 5% of doctors made, how much the first 10% made, and so on.

<div id="inequality-chart">
  <svg style="height:500px;"></svg>
</div>


<script>
d3.json('chart_data/doctor_inequality.json', function(data) {
  nv.addGraph(function() {
    var chart = nv.models.lineChart()
                  .color(d3.scale.category10().range())
                  .useInteractiveGuideline(true)
                  ;
  
  data = [{
      values: data,      //values - represents the array of {x,y} data points
      key: 'Cumulative payment percentage', //key  - the name of the series.
      color: '#ff7f0e'  //color - optional: choose your own line color.
    }];
    
  chart.xAxis     //Chart x-axis settings
      .axisLabel('Percentage of Doctors')
      .tickFormat(d3.format(',r'));

  chart.yAxis     //Chart y-axis settings
      .axisLabel('Percentage of Payments')
      .tickFormat(d3.format('.02f'));

    d3.select('#inequality-chart svg')
        .datum(data)
        .call(chart);

    //TODO: Figure out a good way to do this automatically
    nv.utils.windowResize(chart.update);

    return chart;
  });
});
</script>

The above plot shows how stark the inequality is.  The bottom 75% of doctors get 25% of the payments.  The top 5% get 47% of all payments.  Doctors in this case also includes nurses and other practitioners who get Medicare reimbursement, along with doctors who don't bill Medicare much, so these numbers are likely too extreme.

### Gender based numeric inequality

We can also look at the data by gender.  Overall, there are `523085` male physicians, and `302023` female.  

Let's break down most common occupations by gender.

```
common_occupations = names(tail(sort(table(docs$provider_type)),15))
occupations = do.call(rbind,lapply(common_occupations, function(x){
  data.frame(occupation=x, female_count=nrow(females[females$provider_type==x,]), male_count=nrow(males[males$provider_type==x,]))
}))
```

This will give us a list of the 10 most common occupations, and how many males and females are doing them.  Let's make a chart:

<div id="occupation-chart">
  <svg style="height:500px;width=500px;"></svg>
</div>

<script>
  d3.json('chart_data/occupations.json', function(data) {
    nv.addGraph(function() {
      var chart = nv.models.multiBarHorizontalChart()
                  .x(function(d) { return d.label })
                  .y(function(d) { return d.value })
                  .showValues(true)           //Show bar value next to each bar.
                  .tooltips(true)             //Show tooltips on hover.
                  .transitionDuration(350)
                  .margin({top: 30, right: 20, bottom: 50, left: 175})
                  .showControls(true);        //Allow user to switch between "Grouped" and "Stacked" mode.
                  
      var new_dat = [
          {
            key: "Males",
            color: "#4f99b4",
            values: []
          },
          {
            key: "Females",
            color: "#d67777",
            values: []
          }
      ];
      for(var i=0;i < data.length;i++){
        var label = data[i].occupation;
        new_dat[0].values.push({
          label: label,
          value: data[i].male_count
        });
        new_dat[1].values.push({
          label: label,
          value: data[i].female_count
        });
      }
      
      console.log(new_dat);
      
      
      chart.yAxis
          .tickFormat(d3.format(',r'));
  
      d3.select('#occupation-chart svg')
          .datum(new_dat)
          .call(chart);
  
      nv.utils.windowResize(chart.update);
  
      return chart;
    });
  });
</script>

We see that women outnumber men in jobs like `Nurse Practitioner` and `Physician Assistant`, whereas there are more men in jobs like `Internal Medicine` and `Emergency Medicine`.  

### Gender based payment inequality

This is interesting, but doesn't tell us much about payments.  Let's look at how much practitioners of each speciality are paid, broken down by gender:

<div id="occupation-pay-chart">
  <svg style="height:500px;width=500px;"></svg>
</div>

<script>
  d3.json('chart_data/occupation_pay.json', function(data) {
    nv.addGraph(function() {
      var chart = nv.models.multiBarHorizontalChart()
                  .x(function(d) { return d.label })
                  .y(function(d) { return d.value })
                  .showValues(true)           //Show bar value next to each bar.
                  .tooltips(true)             //Show tooltips on hover.
                  .transitionDuration(350)
                  .margin({top: 30, right: 20, bottom: 50, left: 175})
                  .showControls(true);        //Allow user to switch between "Grouped" and "Stacked" mode.
                  
      var new_dat = [
          {
            key: "Males",
            color: "#4f99b4",
            values: []
          },
          {
            key: "Females",
            color: "#d67777",
            values: []
          }
      ];
      for(var i=0;i < data.length;i++){
        var label = data[i].occupation;
        new_dat[0].values.push({
          label: label,
          value: data[i].male_count
        });
        new_dat[1].values.push({
          label: label,
          value: data[i].female_count
        });
      }
      
      console.log(new_dat);
      
      
      chart.yAxis
          .tickFormat(d3.format(',r'));
  
      d3.select('#occupation-pay-chart svg')
          .datum(new_dat)
          .call(chart);
  
      nv.utils.windowResize(chart.update);
  
      return chart;
    });
  });
</script>

Men are, on average, reimbursed more from medicare for every single speciality in the top 10 most common.  This is kind of insane, and I don't know how to explain it.  Anyone with insight here would be welcome.

So where are all these doctors, anyways?
------------------------------------------------------------

Let's move from high-level analysis into location based analysis.  One interesting way to do this is to see where the "million dollar doctors" -- the ones who bill the most to medicare -- are.  Let's make a map.

<div id="top-physicians" style="height=500px;"></div>

<script>

d3.json('chart_data/top_docs.json', function(data) {
  	var tiles = L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
				maxZoom: 18,
				attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors, Points &copy 2012 LINZ'
			}),
			latlng = L.latLng(40, -100);

		var map = L.map('top-physicians', {center: latlng, zoom: 4, layers: [tiles]});

		var markers = L.markerClusterGroup();
		
		for (var i = 0; i < data.length; i++) {
			var a = data[i];
			var marker = L.marker(new L.LatLng(a.lat, a.long), { title: a.name });
			marker.bindPopup(a.name + " " + a.payment);
			markers.addLayer(marker);
		}

		map.addLayer(markers);
});

</script>

