.pragma library

function Request() {
    this.method = "GET";
    this.url = "";
    this.headers = null;
    this.data = null;
    this.succesCb = null;
    this.errorCb = null;
    this.req = new XMLHttpRequest();

    this.setMethod = function (method) { this.method = method; return this; }
    this.setUrl = function (url) { this.url = url; return this; }
    this.setHeaders = function (headers) { this.headers = headers; return this; }
    this.setData = function (data) { this.data = data; return this; }
    this.onSuccess = function (successCb) { this.successCb = successCb; return this; }
    this.onError = function (errorCb) { this.errorCb = errorCb; return this; }

    this.send = function () {
        this.req.open(this.method, this.url);

        this.req.onreadystatechange = function () {
            if (this.req.readyState === 4) { //request done
                if (this.req.status === 200 || this.req.status === 204) {
                    if (this.successCb) {
                        this.successCb(this.req.responseText);
                    }
                } else {
                    if (this.errorCb) {
                        this.errorCb(this.req.status, this.req.responseText);
                    }
                }
            }
        }.bind(this);

        for (var k in this.headers) {
            this.req.setRequestHeader(k, this.headers[k])
        }

        this.req.send(this.data);
    }
}
