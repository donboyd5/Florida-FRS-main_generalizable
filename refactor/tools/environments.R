

ecopy <- function(oldenv) {
  # Create a new environment
  newenv <- new.env(parent = emptyenv())
  
  # Copy variables from the old environment to the new environment
  for (name in ls(oldenv)) {
    assign(name, get(name, envir = oldenv), envir = newenv)
  }
  
  # Return the new environment
  newenv
}

ecopy <- function(oldenv, recursive = FALSE) {
  newenv <- new.env(parent = emptyenv())
  
  for (name in ls(oldenv)) {
    value <- get(name, envir = oldenv)
    if (recursive && is.environment(value)) {
      assign(name, ecopy(value, recursive = TRUE), envir = newenv)
    } else {
      assign(name, value, envir = newenv)
    }
  }
  
  newenv
}

# Example usage:
oldenv <- new.env()
oldenv$x <- 7
oldenv$y <- 10

newenv <- ecopy(oldenv)
newenv$x <- 9

# Now newenv has the modified value, while oldenv remains unchanged
print(newenv$x)  # Output: 9
print(oldenv$x)  # Output: 7


ecopy <- function(oldenv, recursive = FALSE) {
  newenv <- new.env(parent = emptyenv())
  
  for (name in ls(oldenv)) {
    value <- get(name, envir = oldenv)
    if (recursive && is.environment(value)) {
      assign(name, ecopy(value, recursive = TRUE), envir = newenv)
    } else {
      assign(name, value, envir = newenv)
    }
  }
  
  newenv
}







# Create an environment with a child environment
parent_env <- new.env()
parent_env$x <- 10
child_env <- new.env(parent = parent_env)
child_env$y <- 20
names(parent_env) # does not have child_env
parent_env$child <- child_env
names(parent_env) # now has child

# Convert the environment to a list
list_env <- as.list(parent_env)

# Inspect the result
print(list_env)








