.pragma library

function Request(httpClient) {
    this.method = "GET";
    this.url = "";
    this.headers = null;
    this.data = null;
    this.succesCb = null;
    this.errorCb = null;
    this.req = httpClient;

    this.setMethod = function (method) { this.method = method; return this; }
    this.setUrl = function (url) { this.url = url; return this; }
    this.setHeaders = function (headers) { this.headers = headers; return this; }
    this.setData = function (data) { this.data = data; return this; }
    this.onSuccess = function (successCb) { this.successCb = successCb; return this; }
    this.onError = function (errorCb) { this.errorCb = errorCb; return this; }

    this.requestSuccess = function(statusCode, message) {
        if (this.successCb) {
            this.successCb(message);
        }
    }.bind(this);

    this.requestError = function(statusCode, errorString) {
        if (this.errorCb) {
            this.errorCb(statusCode, errorString);
        }
    }.bind(this);

    this.req.onSuccess.connect(this.requestSuccess);
    this.req.onError.connect(this.requestError);

    this.send = function () {
        this.req.setMethod(this.method);
        this.req.setUrl(this.url);
        this.req.setData(this.data);

        for (var k in this.headers) {
            this.req.setRequestHeader(k, this.headers[k])
        }

        if (this.data) {
            this.req.send(this.data);
        } else {
            this.req.send();
        }
    }
}
