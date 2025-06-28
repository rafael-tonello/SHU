#todo: ensure msic.sh
#todo: ensure stream.sh

#implements IWorkable interface
GitTools.New(){
    o.New GitTools; local gt="$_r"
    if [ ! -z "$_error" ]; then
        _error="GitTools.New failed: $_error"
        return 1
    fi

    Stream.New; local newBranchStream="$_r"
    Stream.New; local newCommitStream="$_r"
    Stream.New; local newTagStream="$_r"

    if [ ! -z "$_error" ]; then
        _error="Stream.New failed: $_error"
        return 1
    fi

    o.Set "$gt.newBranchStream" "$newBranchStream"
    o.Set "$gt.newCommitStream" "$newCommitStream"
    o.Set "$gt.newTagStream" "$newTagStream"
}

#redirects to newBranchStream.subscribe
GitTools.ListeNewBranches(){
}

#redirects to newCommitStream.subscribe
GitTools.ListeNewCommits(){
}

#redirects to newTagStream.subscribe
GitTools.ListeNewTags(){
}

GitTools.ListCommits(){ local branchOrTag="$1";

}

GitTools.ListBranches(){ 

}

GitTools.ListTags(){

}

#create tag and send to server
GitTools.CreateTag(){ local tagName="$1"; local commitOrBranch="$2";

}

#create branch and send to server
GitTools.CreateBranch(){ local branchName="$1"; local fromBranch="$2";

}

#commit changes and send to server
GitTools.Commit(){ local commitMessage="$1"; local branchOrTag="$2";

}
