# Check if we have been included already
[[ -n "${HACKING_BASH_LIB_LOADED+x}" ]] && return || HACKING_BASH_LIB_LOADED="true"

# Debug flags
#
# DEBUG_get_next_array_index

###################################################################################################
#                                                                                                 #
#                                   Error Handling and Debuging                                   #
#                                                                                                 #
###################################################################################################

# Function to quit with error
# 
#	@in_param	$1 - The error message to die with
#
function die
{
	error_echo "${1}"
	exit 1
}

# Function to send an error message (prefixed with ERROR:) to stderr
# 
#	@in_param	$1 - The error message to send
#
function error_echo
{
    echo "ERROR: ${1}" >&2
	logger -p local1.error "ERROR: ${1}"
	return 0
}

function debug_echo
{
	is_undefined_or_unset DEBUG && is_undefined_or_unset LOGGING && return
	
	v=$(printf "%-${DEBUG_INDENT}s" " ")
	is_defined_and_set DEBUG && echo "debug:${v}${*}" >> "${DEBUG_OUT}"
	is_defined_and_set LOGGING && logger -p local1.warn "debug:${v}${*}"
	return 0
}

# Function to display an array if in debug mode.
#
#	@in_param	$+ - The name(s) of the array variable(s)
#
function debug_echo_array
{
	is_undefined DEBUG && is_undefined LOGGING && return
	
	(( $# < 1 )) && die "debug_echo_array() called with no parameters"

	while (( $# > 0 )); do
		local AS AX IX FIRST MSG
	
		AS="echo $""{!${1}[*]}"
		AX=$(eval "${AS}")
		
		MSG="$1={"
		
		FIRST=""
		for IX in ${AX}; do
			AS="echo $""{${1}[${IX}]}"
			AX=$(eval "${AS}")
	
			[[ -n "${FIRST}" ]] && MSG+=", " || FIRST="no"
	
			MSG+="[${IX}]=\"${AX}\""
		done
		
		MSG+="}"
		debug_echo "${MSG}"
		
		shift
	done
}

function debug_function_calls
{
    is_undefined_or_unset DEBUG && is_undefined_or_unset LOGGING && return
    test -n "$(declare -f "$1")" || die "debug_function_calls() called with non-existent function name [$1]"
    
    rename_function "$1" "debug_function_calls_$1"
    eval "function $1() { debug_function_enter \"$1\" \"\$@\"; debug_function_calls_$1 \"\$@\"; debug_function_return; }"
}

function debug_function_enter
{
	is_undefined_or_unset DEBUG && is_undefined_or_unset LOGGING && return
	
	debug_echo "function ${*}"
	debug_echo "{"
	DEBUG_INDENT=$(( DEBUG_INDENT + 4 ))
}

function debug_function_return
{
	is_undefined_or_unset DEBUG && is_undefined_or_unset LOGGING && return

	(( DEBUG_INDENT >= 4 )) && DEBUG_INDENT=$(( DEBUG_INDENT - 4 ))
    debug_echo "} ${*}"
}

function is_function_defined
{
    test -n "$(declare -f "$1")"
}

# Function to copy a function
#
#   @in_param   $1 - The name of the function to copy
#   @in_param   $2 - The name of the copy of the function
#
function copy_function 
{
    (( $# < 2 )) && die "copy_function() called with insufficient function names"
    
    test -n "$(declare -f "$2")" && die "copy_function() called with existent destination function name [$2]"
    test -n "$(declare -f "$1")" || die "copy_function() called with non-existent source function name [$1]"

    eval "${_/$1/$2}"
}

# Function to delete a function
#
#   @in_param   $1 - The name of the function to delete
#
function delete_function 
{
    (( $# < 1 )) && die "delete_function() called with no function name"

    test -n "$(declare -f "$1")" || die "delete_function() called with non-existent source function name [$1]"
    unset -f "$1"
}

# Function to rename a function
#
#   @in_param   $1 - The original name of the function
#   @in_param   $2 - The new name of the function
#
function rename_function 
{
    (( $# < 2 )) && die "rename_function() called with insufficient function names"
    
    test -n "$(declare -f "$2")" && die "rename_function() called with existent destination function name [$2]"
    test -n "$(declare -f "$1")" || die "rename_function() called with non-existent source function name [$1]"
    
    copy_function "$1" "$2"
    delete_function "$1"
}


###################################################################################################
#                                                                                                 #
#                                         Variable Testing                                        #
#                                                                                                 #
###################################################################################################

# Function to test if a variable is defined.
#
#	@in_param	$1 - The name of the variable
#
function is_defined
{
	# If we were called with no parameters then quit with an error
	[[ -z "${1+x}" ]] && die "is_defined() called with no variable name"
	
	# If the variable is undefined (and not just empty) then return false
	[[ -z "${!1+x}" ]] && return 1
	
	return 0
}

# Function to test if a variable is defined and has a value other than ""
#
#	@in_param	$1 - The name of the variable
#
function is_defined_and_set
{
	# If we were called with no parameters then quit and debug_echo a warning
	[[ -z "${1+x}" ]] && die "is_defined() called with no parameters"
	
	# If the variable is undefined (and not just empty) then return false.
	[[ -z "${!1+x}" ]] && return 1
	
	# If the variable is empty then return false.
	[[ -z "${!1}" ]] && return 1
	
	# We got this far, it must be defined and set
	return 0
}

# Function to test if a variable is undefined.
#
#	@in_param	$1 - The name of the variable
#
function is_undefined
{
	# If we were called with no parameters then quit and debug_echo a warning
	[[ -z "${1+x}" ]] && die "is_undefined() called with no parameters"
	
	# If the variable is undefined (and not just empty) then return true
	[[ -z "${!1+x}" ]] && return 0
	
	return 1
}

# Function to test if a variable is undefined or unset.
#
#	@in_param	$1 - The name of the variable
#
function is_undefined_or_unset
{
	# If we were called with no parameters then quit and debug_echo a warning
	[[ -z "${1+x}" ]] && die "is_undefined() called with no parameters"
	
	# If the variable is undefined (and not just empty) then return true.
	[[ -z "${!1+x}" ]] && return 0
	
	# If the variable is unset then return true.
	[[ -z "${!1}" ]] && return 0
	
	# We got this far so it must be defined and set
	return 1
}

# Function to test if a value is a valid positive integer
#
#	@in_param	$1 - The value to test
#
function is_positive_integer
{
	(( $# < 1 )) && return 1
	
	[[ $1 =~ ^([1-9][0-9]*|0)$ ]] && return 0
	
	return 1
}

# Function to test if a value is a valid negative integer
#
#	@in_param	$1 - The value to test
#
function is_negative_integer
{
	(( $# < 1 )) && return 1
	
	[[ $1 =~ ^(-[1-9][0-9]*|0)$ ]] && return 0
	
	return 1
}

# Function to test if a value is a valid (positive or negative) integer
#
#	@in_param	$1 - The value to test
#
function is_integer
{
	(( $# < 1 )) && return 1
	[[ $1 =~ ^(-?[1-9][0-9]*|0)$ ]] && return 0

	
	return 1
}

###################################################################################################
#                                                                                                 #
#                                       Array Manipulation                                        #
#                                                                                                 #
###################################################################################################

# Function to get the next index in an [indexed] array
#
#	@in_param	$1 - The name of the array variable
#	@in_param	$2 - The current index (optional)
#	@echo	   	   - The number of the next index or an empty string if none.
#
function get_next_array_index
{
    # If we were called with incorrect parameters then die
    [[ -z "${1+x}" ]] && die "get_next_array_index() called with no array variable"

	is_defined_and_set DEBUG_get_next_array_index && debug_function_enter "get_next_array_index" "${@}"
	
	# Make a query to obtain the indexes and evaluate it.
	AS="echo $""{!${1}[*]}"
	AX=$(eval "${AS}")
	
	is_defined_and_set DEBUG_get_next_array_index && debug_echo "array access string: ${AS}" 
	is_defined_and_set DEBUG_get_next_array_index && debug_echo "array indices: ${AX}"
	
	# If we were not passed an index, or the index was an empty string... 
	if (( $# < 2 )) || [[ -z "${2}" ]]; then
		# Echo the first index, if there is one.
		for IX in ${AX}; do
			is_defined_and_set DEBUG_get_next_array_index && debug_echo "found first index: ${IX}"
			echo "${IX}"
			is_defined_and_set DEBUG_get_next_array_index && debug_function_return
			return
		done
	else				
		# Loop through the indexes...
		for IX in ${AX}; do
			# If this index has a greater value than $2 then we've found it...
			if (( IX > ${2} )); then
				# Echo the index and return.
				is_defined_and_set DEBUG_get_next_array_index && debug_echo "found next index: ${IX}"
				echo "${IX}"
				is_defined_and_set DEBUG_get_next_array_index && debug_function_return
				return
			fi
		done
	fi
	
	# If we got this far then we never found the next index.
	is_defined_and_set DEBUG_get_next_array_index && debug_echo "found no next index"
	is_defined_and_set DEBUG_get_next_array_index && debug_function_return 1
	return 1
}

###################################################################################################
#                                                                                                 #
#                                        Global Variables                                         #
#                                                                                                 #
###################################################################################################

DEBUG_INDENT=0
DEBUG_OUT="/dev/stderr"

