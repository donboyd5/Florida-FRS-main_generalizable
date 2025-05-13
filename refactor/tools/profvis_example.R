
# https://www.youtube.com/watch?v=8Ci8B1GH0Qo (not source of example below)
# https://github.com/joshuaulrich/microbenchmark/

library(profvis)

# https://www.rdocumentation.org/packages/profvis/versions/0.3.8/topics/profvis
# Only run these examples in interactive R sessions
if (interactive()) {
  
  # Profile some code
  profvis({
    dat <- data.frame(
      x = rnorm(5e4),
      y = rnorm(5e4)
    )
    
    plot(x ~ y, data = dat)
    m <- lm(x ~ y, data = dat)
    abline(m, col = "red")
  })
  
  
  # Save a profile to an HTML file
  p <- profvis({
    dat <- data.frame(
      x = rnorm(5e4),
      y = rnorm(5e4)
    )
    
    plot(x ~ y, data = dat)
    m <- lm(x ~ y, data = dat)
    abline(m, col = "red")
  })
  htmlwidgets::saveWidget(p, "profile.html")
  
  # Can open in browser from R
  browseURL("profile.html")
  
}


profvis({			
  dat <- data.frame(			
    x = rnorm(5e4),			
    y = rnorm(5e4)			
  )			
  
  plot(x ~ y, data = dat)			
  m <- lm(x ~ y, data = dat)			
  abline(m, col = "red")			
})

