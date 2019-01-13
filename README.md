# Please Note, this read me is a WIP and will be impoved upon.

# auto-app-version
An Azure DevOps build and release task designed to automatically increment your app's version number. 

## So what is this? Simply put...
Don't worry about incrementing you'r apps version number everytime you commit/integrate and deploy small patch updates, there's going to be a lot of them, let AutoAppVersion increment the patch version for you. When you are ready to release a new Major or Minor version, simply update those version segmants like normal in your csporj file, and AutoAppVersion will reset the patch segment for you.

## What?  
AutoAppVersion will read your project's csproj file looking for the version element. Depending on the the version format, and a version number saved from your previous build, a new version number will be generated. The new version number will be saved back into the build's csproj file. Additional pipeline tasks such as deploying and packing will now make use of the new, incremented version number inside the csproj file.  
  
## Why?
I simply made this because I kept on forgetting to update my version number whenever I commited a change. Utilising Azure DevOps CD/CI pipelines, and in some cases automatically re-packing and pushing packages meant, that if (and when) I forgot to update the version number, the release pipeline would fail because "Package with same name and Version number already exists"

## How?
Set your version number in your project's csproj file. It is here you will also define a format (or mask). Typically if you are planning on packaging your project, you will have a `<PropertyGroup>` element which defines certain package information. It's the `<Version>` element we care about.
  
```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>...</TargetFramework>
        <PackageId>...</PackageId>
        <Version>1.0.0</Version>
    </PropertyGroup>
    ...
</Project>
```
  
Decide which segment of your version number you want to automate. Though, you can automate the Major, Minor and Patch segments, it is suggested you only automate the patch segment. Replacing a segment's value with $ informs AutoAppVersion the this segment is to be automated.
  
```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        ...
        ...
        <Version>1.0.$</Version>
    </PropertyGroup>
    ...
</Project>
```
  
Incrementing higher priority segments manually will result in lower priority, automated segments being set back to 0.
  
Major (Highest Priority)  
Minor (Medium Priority)  
Patch (Lowest Priority)  
  
If we take the version format example above `1.0.$`. The final version output will always start with `1.0.` and patch will be incremented. Lets say you've deplyed, several times without manually updating your version number, and the current version number is `1.0.14`, incrementing either Major or Minor segments will cause the patch value to return to 0:
  
e.g `<Version>1.1.$</Version>` the next output number will be `1.1.0`, `1.1.1`, `1.1.2` etc  
  
the same will hapen if you increment the Major version:  
  
e.g `<Version>2.1.$</Version>` the next output number will be `2.1.0`, `2.1.1`, `2.1.2` etc  
  
Any version segment that is hardcoded is still your responsibility to maintain. In the examples above, if you had changed yopur minor version number from `<Version>1.0.$</Version>` to `<Version>1.1.$</Version>`, then you wanted to increase the major version to 2, it is your responsibility to reset the minor version e.g `<Version>2.0.$</Version>`. AutoAppVersion will automatically acknowledge this change and set the patch value back to 0 on the next deployment.  
  
the newly calculated version number is saved back to the project file, ultimatly overwriting the mask. Don't be alarmend by this, these files are only for use during this particular build or release.  
  
The final thing AutoAppVersion will do is save the new version number so it knows where to increment from on the next build. This is done by api, a http request is made against the current pipeline definition and the specified `VersionVariable` is updated.
  
## What happens if...
Here's what happens if you mask your version number any other way then outlined above:  
  
`<Version>2.$.0</Version>` = `2.0.0`, `2.1.0`, `2.2.0`, `2.3.0`  
`<Version>2.$.6</Version>` = `2.0.6`, `2.1.6`, `2.2.6`, `2.3.6`  
`<Version>$.0.0</Version>` = `0.0.0`, `1.0.0`, `2.0.0`, `3.0.0`  
`<Version>$.5.8</Version>` = `0.5.8`, `1.5.8`, `2.5.8`, `3.5.8`  
  
## Multi mask...
`<Version>$.5.$</Version>` = `0.5.0`, `1.5.0`, `2.5.0`, `3.5.0`  
`<Version>1.$.$</Version>` = `1.0.0`, `1.1.0`, `1.2.0`, `1.3.0`  
`<Version>$.$.$</Version>` = `0.0.0`, `1.0.0`, `2.0.0`, `3.0.0`  
  
Notice how a second or third masked values are always 0, this is because a higher priority segment value has been increased, AutoAppVersion will always set lower priority, masked segments to 0 if it detects a higher priority segment's value has increased.
