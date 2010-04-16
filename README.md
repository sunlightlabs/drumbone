**NOTE**: See more complete documentation, with better examples, on Sunlight's [official documentation for our APIs](http://services.sunlightlabs.com/docs/Drumbone_API/)


Drumbone is a RESTful JSON API over data about legislators, bills, and roll call votes.  Unlike the [Sunlight Labs Congress API](http://services.sunlightlabs.com/docs/Sunlight%20Congress%20API/), all data is taken from existing APIs and data sources (especially [GovTrack](http://govtrack.us)); there is no original data here.  

The name "Drumbone" is taken from the name of an instrument created from PVC pipes whose length can be adjusted as needed to create various sounds and music.  Accordingly, the purpose of Drumbone is to pipe in data from disparate sources, and redistribute it in the simplest and most flexible format possible.

Drumbone is designed to serve thin clients, and applications where bandwidth is at a premium.  It was originally built to serve a mobile app, the [Congress Android app](http://sunlightlabs.com/blog/2009/congress-theres-an-android-app-for-that/)), and a widget service, Sunlight's [Politiwidgets](http://politiwidgets.com).  The idea is to give you all the information you need to fill in a user interface in one HTTP call.  It is **not** meant to serve as a bulk data repository.  Drumbone uses [GovTrack](http://www.govtrack.us/developers/data.xpd) for that, and so should you.

Drumbone is written in Ruby, with the [Sinatra](http://www.sinatrarb.com/) framework, and uses [MongoDB](http://mongodb.org) for data storage.  The code for this service is [available on Github](http://github.com/sunlightlabs/drumbone).


### Getting Started

* [Register for a Sunlight Services API Key](/accounts/register/)
* Read through this documentation
* Ask questions/show off your project on the [Sunlight API Google Group](http://groups.google.com/group/sunlightlabs-api-
discuss)


#### API Details

The URL structure is:

http://drumbone.services.sunlightlabs.com/v1/api/[**method**].json

All responses are in JSON.  XML is not likely to be supported.

You must pass in a Sunlight Labs API key in order to use the service.  This can be provided in the query string, using the format "apikey=[yourApiKey]", or as an HTTP request header named "X-APIKEY".

This is version **1** of the API.  New data and methods may be added to it without notification, but no data will be removed, and no backwards-incompatible changes will be made without seeking community input, or advancing to a version 2.


##### Data and Methods

There are 3 kinds of documents in the API:

* [Legislator](http://services.sunlightlabs.com/docs/Drumbone_API/Legislator/) - A legislator in Congress.  Legislators go as far back as the [Sunlight Labs Congress API](http://services.sunlightlabs.com/docs/Sunlight%20Congress%20API/).
* [Bill](http://services.sunlightlabs.com/docs/Drumbone_API/Bill/) - A bill, or resolution, in Congress.  Bills go as far back as the **111th** Congress.  Data is entirely provided by [GovTrack](http://govtrack.us).
* [Roll](http://services.sunlightlabs.com/docs/Drumbone_API/Roll/) - A roll call vote by the House or Senate.  Roll calls go as far back as the **111th** Congress.  Data is entirely provided by [GovTrack](http://govtrack.us).  


And 5 methods:

* 3 singular methods - **legislator**, **bill**, **roll**
* 2 plural methods - **bills**, **rolls**

Singular methods return one document, and require a unique key to locate it.  If the unique key is missing or not found, a 404 response will be returned (except for JSONP - see the "JSONP" section for details).

Plural methods return an array of documents.  These methods accept various filtering parameters (for example, an "enacted" flag for bills), an "order" parameter for sorting, and pagination parameters.

Look at the page for each document type, linked above, to see the set of unique keys, filtering parameters, and ordering parameters available for each.


##### Partial Responses

By default, responses will return the entire set of information in each document.  This is often quite large, especially for bills and roll calls, and usually you'll only want a specific subset of the document.

You can specify exactly which fields of the document you want using a "sections" parameter, using commas to separate multiple sections.

Every field on the document is its own section. There is also a "magic" section called **basic** on every document, which will return a specific set of scalar values at the top level of the document.  The contents of the "basic" section are listed on the page for each document type: [legislators](http://services.sunlightlabs.com/docs/Drumbone_API/Legislator/), [bills](http://services.sunlightlabs.com/docs/Drumbone_API/Legislator/), and [roll calls](http://services.sunlightlabs.com/docs/Drumbone_API/Legislator/).

You can get more granular and request subsections by using the dot operator to dive down through the document (e.g. "contracts.total_amount", "voters.L000551"). Think of it as accessing the document as a JSON object in JavaScript.

##### JSONP support

Drumbone supports JSONP.  If you pass in a query string parameter named "callback", this will trigger a JSONP response, with the data wrapped inside a call to the value of the "callback" parameter.

**Important** - 404 errors are handled differently for JSONP requests.  Normally, if your call to a singular method ("legislator", "bill", "roll") doesn't have a result, you'll get a 404 error code.  However, since JSONP requests are typically done inside of a browser, using a script tag and not an XmlHttpRequest, your callback would simply never be executed if a 404 occurred.  

For this reason, JSONP requests that would ordinarily result in a 404 will result in a **200** response code, whose response body will be a JSON document with a root key of "error".  Your JavaScript callback method should expect this possibility.

##### Pagination

Results for plural methods are paginated. To control it, use "page" and "per_page" parameters to specify how many results you want, and where to start from.  The default number of documents per page is 20, and can be set to a maximum of 500.