function y=g(x,t,k)
    D=1;
    y=1/(sqrt(4*pi*D*t))*exp(-(k-x).^2/(4*D*t));
end
