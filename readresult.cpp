#include "readresult.h"

bool ReadResult::getError() const {
    return error;
}

QString ReadResult::getErrorString() const {
    return errorString;
}

QString ReadResult::getResult() const {
    return result;
}
