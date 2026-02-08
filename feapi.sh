#!/usr/bin/env bash
# --------------------------
# -- feapi.sh script
# 
# -------------------------

# ------------
# -- Variables
# ------------
SCRIPT_NAME=feapi
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
VERSION="$SCRIPTPATH/VERSION"
API_URL="https://api.forwardemail.net"
REQUIRED_APPS=("jq" "column")

# -- Colors
export TERM=xterm-color
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

NC='\e[0m' # No Color
CRED='\e[0;31m'
CGREEN='\e[0;32m'
CCYAN='\e[0;36m'
CLIGHT_CYAN='\e[1;36m'
BGYELLOW='\e[43m'
CBLACK='\e[30m'

# -- Check for key files
[[ -f .test ]] && TEST=$(<$SCRIPTPATH/.test) || TEST="0"
[[ -f .debug ]] && DEBUG=$(<$SCRIPTPATH/.debug) || DEBUG="0"
[[ -z $DEBUG ]] && DEBUG="0"
[[ -z $TEST ]] && TEST="0"

# ----------------
# -- Key Functions
# ----------------
_debug () {
    if [[ $DEBUG -ge "1" ]]; then
        echo -e "${CCYAN}**** DEBUG ${*}${NC}"
    fi
}

_debug_curl () {
	if [[ $DEBUG -ge "2" ]]; then
    	echo -e "${CCYAN}**** DEBUG ${*}${NC}"
    fi
}


_debug_all () {
    _debug "--------------------------"
    _debug "arguments - ${*}"
    _debug "funcname - ${FUNCNAME[*]}"
    _debug "basename - $SCRIPTPATH"
    _debug "sourced files - ${BASH_SOURCE[*]}"
    _debug "test - $TEST"
    _debug "--------------------------"
}

_error () { echo -e "${CRED}${*}${NC}"; }
_success () { echo -e "${CGREEN}${*}${NC}"; }
_loading () { echo -e "${BGYELLOW}${CBLACK}${*}${NC}"; }
_loading2 () { echo -e "${CLIGHT_CYAN}${*}${NC}"; }

_command () {
	if ! command -v $1 &> /dev/null
	then
	    _error "The command $1 could not be found and is required to run $SCRIPT_NAME"
	    exit
	fi
}

_check_commands () {
    _debug "Checking for required commands"
	for cmd in "${REQUIRED_APPS[@]}"; do
        _debug "Checking for $cmd"
		_command "$cmd"	
	done
}

# =================================================================================================
# -- Debug
# =================================================================================================
_debug_all "${*}"

if [[ $TEST == "1" ]]; then
        _debug "Testing get using .test_get file"
        TEST_FILE=$(<$SCRIPTPATH/tests/test_get)
elif [[ $TEST == "2" ]]; then
	_debug "Testing post using .test_post file"
	TEST_FILE=$(<$SCRIPTPATH/tests/test_post)
elif [[ $TEST == "3" ]]; then
        _debug "Testing error using .test_error file"
        TEST_FILE=$(<$SCRIPTPATH/tests/test_error)
elif [[ $TEST == "4" ]]; then
        _debug "Testing create-alias using .test_create file"
        TEST_FILE=$(<$SCRIPTPATH/tests/test_create)
elif [[ $TEST == "5" ]]; then
        _debug "Testing create-alias using .test_create file"
        TEST_FILE=$(<$SCRIPTPATH/tests/test_delete)
else
        _debug "Testing mode off -- .test=$TEST"
fi

# =================================================================================================
# -- Functions
# =================================================================================================

# ===============================================
# -- usage
# ===============================================
usage () {
	echo "Usage: $SCRIPT_NAME <commands> <args>|<options>"
	echo 
	echo " Commands"
    echo " --------"
    echo " -la, --list-aliases <domain>                               List aliases for a domain"
    echo " -ld, --list-domains <domain>                               List domains"
    echo " -va, --view-alias <alias@domain>                           View alias"
    echo " -ca, --create-alias <alias@domain> <email1,email2,email3>  Create alias"
    echo " -da, --delete-alias <alias@domain>                         Delete alias"
    echo " -t, --tests <test>                                         Run tests"
    echo
    echo " Options"
    echo " -------"
    echo " -d, --debug <debug>                                        Debug mode"
	echo 
	echo " Ensure you hav your forwardemail.net API credentials in \$HOME/.feapi in the following format"
	echo " API_KEY=1v34b21b43234b"
        echo 
	echo "Version: $(<$VERSION)"
}

# ===============================================
# -- split_email - Split email into alias/domain
# -- $1 = email
# ===============================================
split_email () {
	email="$@"
	IFS=$'@' 
	email=($email)
	unset IFS
        ALIAS=${email[0]}
        DOMAIN=${email[1]}
}

# ===============================================
# -- curl_error_message - Print error message
# -- $1 = OUTPUT
# ===============================================
curl_error_message () {
        status=$(echo "$@" | jq -r '[.message, .statusCode] | @tsv')
        IFS=$'\t'
        status=($status)
        QUERY_MESSAGE=${status[0]}
        QUERY_CODE=${status[1]}

        echo ""
        _error "Query Error"
        _error "Query Message: $QUERY_MESSAGE"
        _error "Status Code: $QUERY_CODE"
        exit
}

# ===============================================
# -- curl_check - Check for curl errors
# ===============================================
curl_check () {
        if [[ $OUTPUT == *"Bad Request"* ]]; then
                _debug "curl error"
                curl_error_message $OUTPUT
        elif [[ $OUTPUT == *"Not Found"* ]]; then
                _debug "curl error"
                curl_error_message $OUTPUT
        else
                _debug "curl success"
                _success "Query success"
        fi
}

# ===============================================
# -- curl_get - Get data from API
# -- $1 = query
# ===============================================
curl_get () {
	QUERY=$1
	CURL_QUERY="$API_URL$QUERY"

	_debug "curl_get"

        if (( $TEST >= "1" )); then
		_debug "query: $TEST_FILE"
                OUTPUT=$TEST_FILE
        else
                _debug "query: $QUERY api: $FEAPI_TOKEN"
                _debug "cmd: curl -sX GET $CURL_QUERY -u $FEAPI_TOKEN:"

                # Create a temporary file to store headers
                HEADER_FILE=$(mktemp)

                # Perform the curl request and store headers in the temporary file
                OUTPUT=$(curl -sX GET $CURL_QUERY -u $FEAPI_TOKEN: -D $HEADER_FILE)
                CURL_EXIT_CODE=$?                
                _debug "curl exit code: $CURL_EXIT_CODE"
                
                # Extract the X-Page-Count header
                X_PAGE_COUNT=$(grep -i 'X-Page-Count' $HEADER_FILE | awk '{print $2}')
                X_PAGE_CURRENT=$(grep -i 'X-Page-Current' $HEADER_FILE | awk '{print $2}')
                X_PAGE_SIZE=$(grep -i 'X-Page-Size' $HEADER_FILE | awk '{print $2}')
                X_ITEM_COUNT=$(grep -i 'X-Item-Count' $HEADER_FILE | awk '{print $2}')
                _debug "X-Page-Count: $X_PAGE_COUNT"
                _debug "X-Page-Current: $X_PAGE_CURRENT"
                _debug "X-Page-Size: $X_PAGE_SIZE"
                _debug "X-Item-Count: $X_ITEM_COUNT"

                # Check statusCode json
                curl_check "$OUTPUT"
                _debug_curl "$OUTPUT"
        fi
}

# ===============================================
# -- curl_get_paged - Get data from API with pagination
# -- $1 = query
# -- $2 = paged
# ===============================================
curl_get_paged () {
    local QUERY="$1"
    local PAGED=${2:-0}
    local CURL_QUERY="$API_URL$QUERY"
    if [[ $PAGED == "1" ]]; then
        CURL_QUERY+="?paginate=true"
    fi    
    local DFUNC="curl_get_paged"
    _debug "$DFUNC: \$QUERY=$QUERY \$CURL_QUERY=$CURL_QUERY \$PAGED=$PAGED"

    if (( $TEST >= "1" )); then
        _debug "$DFUNC: Running test query"
        OUTPUT=$TEST_FILE
    else
        _debug "$DFUNC: Running live"
        
        # Initialize an empty array to hold the combined results
        COMBINED_RESULTS=()
        
        # Initialize page counter
        PAGE=1
        
        while true; do
            # Perform the curl request and store the output (headers + body) in a variable            
            HEADER_FILE=$(mktemp)
            [[ $PAGED -eq 1 ]] && CURL_QUERY+="&page=$PAGE"
            _debug "$DFUNC: cmd=curl -sX GET $CURL_QUERY -u $FEAPI_TOKEN: -D $HEADER_FILE"            
            RESPONSE=$(curl -sX GET "$CURL_QUERY" -u $FEAPI_TOKEN: -D $HEADER_FILE)
            CURL_EXIT_CODE=$?
            _debug "$DFUNC: Page $PAGE: ${#RESPONSE} bytes"
            _debug "$DFUNC: curl exit code: $CURL_EXIT_CODE"
            
            # Extract the X-Page-Count header
            X_PAGE_COUNT=$(grep -i 'X-Page-Count' $HEADER_FILE | awk '{print $2}' | tr -d '\r')
            X_PAGE_CURRENT=$(grep -i 'X-Page-Current' $HEADER_FILE | awk '{print $2}' | tr -d '\r')
            X_PAGE_SIZE=$(grep -i 'X-Page-Size' $HEADER_FILE | awk '{print $2}' | tr -d '\r')
            X_ITEM_COUNT=$(grep -i 'X-Item-Count' $HEADER_FILE | awk '{print $2}' | tr -d '\r')

            _debug "X-Page-Count: $X_PAGE_COUNT X-Page-Current: $X_PAGE_CURRENT X-Page-Size: $X_PAGE_SIZE X-Item-Count: $X_ITEM_COUNT"
            
            # Append the current page's results to the combined results            
            COMBINED_RESULTS+=("$RESPONSE")
            _debug_curl "$DFUNC: Combined results: ${COMBINED_RESULTS[*]}"
            
            # Check if paging is disabled
            if [[ $PAGED -eq 0 ]]; then
                _debug "$DFUNC: Paging disabled"
                break
            fi
            
            # Check if there are more pages
            if [[ $PAGE -eq $X_PAGE_COUNT ]]; then
                _debug "$DFUNC: Last page reached"
                break
            fi

            # Increment the page counter
            PAGE=$((PAGE + 1))
        done
        
        # Combine all JSON results into a single JSON array
        OUTPUT=$(echo "${COMBINED_RESULTS[@]}" | jq -s '. | add')
        
        # Check statusCode json
        curl_check "$OUTPUT"
        _debug_curl "$OUTPUT"
    fi
}

# ===============================================
# -- curl_post - Post data to API
# -- $1 = query
# -- $2 = alias
# -- $3 = emails
# -- $4 = enabled
# ===============================================
curl_post () {
	QUERY=$1
	ALIAS=$2	
        EMAILS=$3
        ENABLED=$4
        CURL_QUERY="$API_URL$QUERY"

	_debug "curl_post"
	
	# If test is set
	if (( $TEST >= "1" )); then
		_debug "Running test query"
        
		echo ""
		echo "sample CURL"
		echo "-----------"
		echo "curl -sX POST $CURL_QUERY -u $FEAPI_TOKEN: \\"
		echo "-d \"name=$ALIAS\" \\"
		echo "-d \"recipients=$EMAILS\""
		echo "-d \"$4\""
		echo ""
		OUTPUT=$TEST_FILE
        else
		_debug "query: $QUERY alias:$ALIAS emails:${EMAILS} enabled:$ENABLED api: $FEAPI_TOKEN"
		_debug "cmd: curl -sX POST $CURL_QUERY -u $FEAPI_TOKEN: -d \"name=$ALIAS\" -d \"recipients=$EMAILS\" -d \"$ENABLED\""		
        OUTPUT=$(curl -sX POST $CURL_QUERY -u $FEAPI_TOKEN: -d "name=$ALIAS" -d "recipients=$EMAILS" -d "$ENABLED")
        _debug_curl $OUTPUT
        fi

	_debug "OUTPUT"
	_debug "------"
	_debug $OUTPUT
	
    if [[ $OUTPUT == *"Bad Request"* ]]; then
        _debug "curl error"
        curl_error_message $OUTPUT
	else
        _debug "curl success"
        _success "Query success"

        fi

}

# ===============================================
# -- curl_delete - Delete data from API
# -- $1 = query
# ===============================================
curl_delete () {
        QUERY=$1
        CURL_QUERY="$API_URL$QUERY"

        _debug "curl_delete"

        if (( $TEST >= "1" )); then
                _debug "query: $TEST_FILE"
                OUTPUT=$TEST_FILE
        else
                _debug "query: $QUERY api: $FEAPI_TOKEN"
                _debug "cmd: curl -sX DELETE $CURL_QUERY -u $FEAPI_TOKEN:"
                OUTPUT=$(curl -sX DELETE $CURL_QUERY -u $FEAPI_TOKEN:)
                _debug_curl $OUTPUT
        fi        
	curl_check
}

# ===============================================
# -- list_domains - List domains
# -- $1 = domain
# ===============================================
list_domains () {
	#GET /v1/domains
	#Querystring Parameter	Required	Type	Description
	#name	No	String (RegExp supported)	Search for domains by name
	#alias	No	String (RegExp supported)	Search for domains by alias name
	#recipient	No	String (RegExp supported)	Search for domains by recipient
	# List aliases
    _loading "-- Listing domains"
    curl_get_paged "/v1/domains"
    _loading2 "Domains"
    echo "-------------------"
    echo "${OUTPUT[@]}" | jq -r '(["ID","DOMAIN","MX","TXT","ALIASES","CREATED","LINK"] | (., map(length*"-"))), (.[] | [.id, .name, .has_mx_record, .has_txt_record, .members[0] .alias_count, .created_at, .link])|@tsv' | column -t
}

# ===============================================
# -- list_aliases - List aliases
# -- $1 = domain
# ===============================================
list_aliases () {
	#GET /v1/domains/domain.com/aliases
	#Querystring Parameter	Required	Type				Description
	#name			No		String (RegExp supported)	Search for aliases in a domain by name
	#recipient		No		String (RegExp supported)	Search for aliases in a domain by recipient	

	# Variables
	DOMAIN=$1
	_debug "domain = $DOMAIN"
	
	# List aliases
	_loading  "-- Listing aliases"
	curl_get_paged "/v1/domains/$DOMAIN/aliases" 1
    _loading2 "${X_ITEM_COUNT} Aliases for $DOMAIN"
	echo "-------------------"
    #echo "${OUTPUT[@]}" | jq -r '(["ID","ENABLED","NAME","RECIPIENTS","DESCRIPTION"] | (., map(length*"-"))), (.[]| [.id, .is_enabled, .name,(.recipients|join(",")),.description])|@tsv' | column -t
    echo "${OUTPUT[@]}" | jq -r 'sort_by(.name) | (["ID","ENABLED","NAME","RECIPIENTS","DESCRIPTION"] | (., map(length*"-"))), (.[]| [.id, .is_enabled, .name,(.recipients|join(",")),.description])|@tsv' | column -t
}

# ===============================================
# -- view_alias - View alias
# -- $1 = alias@domain
# ===============================================
view_alias () {
        # GET /v1/domains/:domain_name/aliases/:alias_id
        # curl https://api.forwardemail.net/v1/domains/:domain_name/aliases/:alias_id -u API_TOKEN:

        # Split email parts
        _debug "splitting email"
        split_email "$@"
        _debug "alias: $ALIAS domain: $DOMAIN"

        # Get data and print
        echo "-- Getting alias ${*}"
        curl_get_paged "/v1/domains/$DOMAIN/aliases/$ALIAS"

        #

        echo "Alias ${*}"
        echo "-----------"
        echo "Name: $(echo ${OUTPUT[@]} | jq -r '.name')"
        echo "ID: $(echo ${OUTPUT[@]} | jq -r '.id')"
        echo "Enabled: $(echo ${OUTPUT[@]} | jq -r '.is_enabled')"
        echo "-----------"
        echo "Recipients $(echo ${OUTPUT[@]} | jq -r '.recipients')"
        #echo "${OUTPUT[@]}" | jq -r '(["ID","ENABLED","NAME","RECIPIENTS","DESCRIPTION"] | (., map(length*"-"))), [.id, .is_enabled, .name,(.recipients|join(",")),.description]|@tsv' | column -t
}

# ===============================================
# -- create_alias - Create alias
# -- $1 = alias@domain
# -- $2 = emails
# ===============================================
create_alias () {
	#POST /v1/domains/domain.com/aliases
	#Body Parameter	Required Type			Description
	#name		Yes	String			Alias name
	#recipients	Yes	String or Array		List of recipients (must be line-break/space/comma separated String 
	#						or Array of valid email addresses, fully-qualified domain names 
	#						("FQDN"), IP addresses, and/or webhook URL's)
	#description	No	String			Alias description
	#labels		No	String or Array		List of labels (must be line-break/space/comma separated String or Array)
	#is_enabled	No	Boolean			Whether to enable to disable this alias (if disabled, emails will be routed 
	#						nowhere but return successful status codes)

	# Variables
	_debug "args: ${*}"
        split_email $1
        EMAILS=$2
        _debug "alias: $ALIAS domain: $DOMAIN emails:$EMAILS"
	
	# Create alias
        echo "-- Creating alias"
        curl_post "/v1/domains/$DOMAIN/aliases" "$ALIAS" "$EMAILS" "is_enabled=true"
        echo "${OUTPUT[@]}" | jq -r '(["ID","ENABLED","NAME","RECIPIENTS"] | (., map(length*"-"))), [.id, .is_enabled, .name,(.recipients|join(","))]|@tsv' | column -t
}

# ===============================================
# -- delete_alias - Delete alias
# -- $1 = alias@domain
# ===============================================
delete_alias () {
	#DELETE /v1/domains/:domain_name/aliases/:alias_id
	#Example Request:
	#curl -X DELETE https://api.forwardemail.net/v1/domains/:domain_name/aliases/:alias_id

        # Variables
        split_email $1
        _debug "alias: $ALIAS domain: $DOMAIN"

        # Create alias
        echo "-- Creating alias"
        curl_delete "/v1/domains/$DOMAIN/aliases/$ALIAS"
        echo "${OUTPUT[@]}" | jq -r '(["ID","ENABLED","NAME","RECIPIENTS","DESCRIPTION"] | (., map(length*"-"))), ([.id, .is_enabled, .name,(.recipients|join(",")),.description])|@tsv' | column -t
}

# ===============================================
# -- tests_cmd - Change test value
# -- $1 = test value
# ===============================================
tests_cmd () {
	echo "Current Test Value = $TEST"
	echo ""
	echo "Test 0 = Testing Disabled"
        echo "Test 1 = test_get"
	echo "Test 2 = test_post"
	echo "Test 3 = test_error"
	echo "Test 4 = test_create"
	echo "Test 5 = test_delete"
	if [[ $1 ]]; then
		echo ""
		echo "Changing test value to $1"
		echo "$1" > $SCRIPTPATH/.test
	fi
}

# ===============================================
# -- debug_cmd - Change debug value
# -- $1 = debug value
# ===============================================
debug_cmd () {
        echo "Current debug value = $DEBUG"
        echo ""
        echo "Debug 0 = Debug disabled"
	echo "Debug 1 = Debug enabled"
	echo "Debug 2 = Debug enabled + curl debug enabled"
        if [[ $1 ]]; then
                echo ""
                echo "Changing debug value to $1"
                echo "$1" > $SCRIPTPATH/.debug
        fi
}

# =================================================================================================
# -- Main script
# =================================================================================================

# -- debug args
ALL_ARGS="${*}"

# -- options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -la|--list-aliases)
        MODE="list-aliases"
        LIST_ALIASES="$2"
        shift # past argument
        shift # past value
        ;;
        -ld|--list-domains)
        MODE="list-domains"
        LIST_DOMAINS="$2"
        shift # past argument
        shift # past value
        ;;
        -va|--view-alias)
        MODE="view-alias"
        VIEW_ALIAS="$2"
        shift # past argument
        ;;
        -ca|--create-alias)
        MODE="create-alias"
        CREATE_ALIAS="$2"
        CREATE_ALIAS_RECIPIENTS="$3"
        shift # past argument
        shift # past value
        shift # past recipients
        ;;
        -da|--delete-alias)
        MODE="delete-alias"
        DELETE_ALIAS="$2"
        shift # past argument
        shift # past value
        ;;
        -t|--tests)
        MODE="tests"
        TESTS="$2"
        shift # past argument
        ;;
        -d|--debug)
        DEBUG="$2"
        shift # past argument
        shift # past value
        ;;
        *)# unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# -- debug args
_debug "ARGS: ${ALL_ARGS}"
_debug "MODE: ${MODE}"

# -- check if required commands are installed
_check_commands

# -- Check for .feapi key
if [[ -f ~/.feapi ]]; then
	_success "Found ~/.feapi"
    source ~/.feapi
elif [[ $FEAPI_TOKEN ]]; then
        _success "Found API key."
else
    _error "No ~/.feapi file exists, and $FEAPI_TOKEN set."
    exit 1
fi

# -- list-aliases
if [[ $MODE == "list-aliases" ]]; then
    _debug "list-aliases args: ${LIST_ALIASES}"
    if [[ -z $LIST_ALIASES ]]; then        
        usage
        _error "No domain specified"
        exit 1
    else
        list_aliases "$LIST_ALIASES"
    fi
# -- list-domains
elif [[ $MODE == "list-domains" ]]; then
    _debug "list-domains args: ${LIST_DOMAINS}"
    if [[ -z $LIST_DOMAINS ]]; then
        usage
        _error "No domain specified"
        exit 1
    else
        list_domains "$LIST_DOMAINS"
    fi
# -- view-alias
elif [[ $MODE == "view-alias" ]]; then
    _debug "view-alias args: ${VIEW_ALIAS}"
    if [[ -z $VIEW_ALIAS ]]; then        
        usage
        _error "No alias specified"
        exit 1
    else
        view_alias "$VIEW_ALIAS"
    fi
# -- create-alias
elif [[ $MODE == "create-alias" ]]; then
    _debug "create-alias args: ${CREATE_ALIAS} ${CREATE_ALIAS_RECIPIENTS}"
    if [[ -z $CREATE_ALIAS ]]; then
        usage
        _error "No alias specified"
        exit 1
    else
        create_alias "$CREATE_ALIAS" "$CREATE_ALIAS_RECIPIENTS"
    fi
# -- delete-alias
elif [[ $MODE == "delete-alias" ]]; then
    _debug "delete-alias args: ${DELETE_ALIAS}"
    if [[ -z $DELETE_ALIAS ]];then
        usage
        _error "No alias specified"
        exit 1
    else
        delete_alias $DELETE_ALIAS
    fi
# -- tests
elif [[ $MODE == "tests" ]]; then
    _debug "tests args: ${TESTS}"
    tests_cmd "$TESTS"
else
    usage
    _error "Invalid command ${*}"
fi