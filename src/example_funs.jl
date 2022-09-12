"""
Ishigamis example function (https://www.sfu.ca/~ssurjano/ishigami.html)
"""
function ishigami_fun(x1,x2,x3) 
    A = 7
    B = 0.1
    sin(x1) + A * sin(x2)^2 + B * x3^4 * sin(x1)
end

