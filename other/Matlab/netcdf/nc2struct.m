function p=nc2struct(filename,varnames,gattnames,times,p)
% p=ncread2str(filename,varnames,g       p.(lower(varname))=[];attnames,times)
% read from netcdf file to structure
%
% arguments
% input
%   filename        string, name of file to read
%   varnames        cell array of strings, names of variable to read
%   gattnames       cell array of strings, names of global attributes to read
%   times           (optional) matrix of indices in the last dimension to extract
%   p               (optional) the structure to add to
% output
%   p               matlab structure with the specifed variables and attributes as fields
%                   with names in lowercase.  The types are kept and the dimensions 
%                   are not squeezed
%
% example
%   p=ncread2struct('wrfinput_d01',{'U','V'},{'DX','DY'})
% will read variables U,V into p.u, p.v and global attributes DX DY into
% p.dx p.dy, respectively


for i=1:length({varnames{:}}),
    varname=varnames{i};
    try
        v=ncvar(filename,varname);
    catch ME
        warning(['variable ',varname,' does not exist in file ',filename])
        v.var_value=[];
    end
    if ~isempty(times) && ~isempty(v.var_value),
        switch ndims(v.var_value)
            case 2
                p.(lower(varname))=v.var_value(:,times);
            case 4
                p.(lower(varname))=v.var_value(:,:,:,times);
            otherwise
                warning('argument times supported only for 2d and 4d arrays')
                p.(lower(varname))=v.var_value;
        end % case
    else
        p.(lower(varname))=v.var_value; 
    end
end

for i=1:length({gattnames{:}}),
    gattname=gattnames{i};
    try
        v=ncgetgatt(filename,gattname);
        p.(lower(gattname))=v;
    catch ME
        warning(['global attribute ',gattname,' does not exist in file ',filename])
        p.(lower(gattname))=[];
    end
end

end