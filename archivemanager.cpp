#include "archivemanager.h"
#include <archive.h>
#include <archive_entry.h>
#include <QDateTime>
#include <QDirIterator>
#include <QFile>

ArchiveEntryModel::ArchiveEntryModel(QObject *p):QAbstractListModel(p){}
int ArchiveEntryModel::rowCount(const QModelIndex&)const{return m_entries.size();}
QVariant ArchiveEntryModel::data(const QModelIndex &i,int role)const{
    if(!i.isValid()||i.row()>=m_entries.size())return{};const auto&e=m_entries[i.row()];
    switch(role){case PathRole:return e.path;case SizeRole:return e.size;case IsDirRole:return e.isDir;
    case ModifiedRole:return e.modified;case FileNameRole:{QString p=e.path;if(p.endsWith('/'))p.chop(1);return p.mid(p.lastIndexOf('/')+1);}}return{};}
QHash<int,QByteArray>ArchiveEntryModel::roleNames()const{return{{PathRole,"path"},{SizeRole,"fileSize"},{IsDirRole,"isDir"},{ModifiedRole,"modified"},{FileNameRole,"fileName"}};}
void ArchiveEntryModel::setEntries(const QVector<ArchiveEntry>&e){beginResetModel();m_entries=e;endResetModel();emit statsChanged();}
void ArchiveEntryModel::clear(){beginResetModel();m_entries.clear();endResetModel();emit statsChanged();}
int ArchiveEntryModel::fileCount()const{int c=0;for(auto&e:m_entries)if(!e.isDir)c++;return c;}
int ArchiveEntryModel::dirCount()const{int c=0;for(auto&e:m_entries)if(e.isDir)c++;return c;}
qint64 ArchiveEntryModel::totalSize()const{qint64 t=0;for(auto&e:m_entries)if(e.size>0)t+=e.size;return t;}
QString ArchiveEntryModel::totalSizeFormatted()const{return ArchiveManager::formatBytes(totalSize());}

ArchiveWorker::ArchiveWorker(QObject *p):QObject(p),m_cancelRequested(0){}
void ArchiveWorker::requestCancel(){m_cancelRequested.storeRelease(1);}

void ArchiveWorker::listContents(const QString &ap){
    auto*a=archive_read_new();archive_read_support_filter_all(a);archive_read_support_format_all(a);
    if(archive_read_open_filename(a,ap.toUtf8().constData(),10240)!=ARCHIVE_OK){
        emit finished(false,"Cannot open: "+QString::fromUtf8(archive_error_string(a)));archive_read_free(a);return;}
    QVector<ArchiveEntry>entries;struct archive_entry*entry;int r;
    while((r=archive_read_next_header(a,&entry))==ARCHIVE_OK||r==ARCHIVE_WARN){
        ArchiveEntry e;const char*n=archive_entry_pathname_utf8(entry);if(!n)n=archive_entry_pathname(entry);
        e.path=n?QString::fromUtf8(n):QString();if(e.path.isEmpty())e.path=QFileInfo(ap).completeBaseName();
        e.size=archive_entry_size_is_set(entry)?archive_entry_size(entry):0;
        e.isDir=(archive_entry_filetype(entry)==AE_IFDIR);
        if(archive_entry_mtime_is_set(entry))e.modified=QDateTime::fromSecsSinceEpoch(archive_entry_mtime(entry)).toString("yyyy-MM-dd hh:mm");
        entries.append(e);archive_read_data_skip(a);}
    archive_read_free(a);emit contentsReady(entries);emit finished(true,QString());}

void ArchiveWorker::extract(const QString &ap,const QString &dp,qint64 ts,int cm){
    m_cancelRequested.storeRelease(0);
    auto*a=archive_read_new();archive_read_support_filter_all(a);archive_read_support_format_all(a);
    auto*ext=archive_write_disk_new();
    int fl=ARCHIVE_EXTRACT_TIME|ARCHIVE_EXTRACT_PERM|ARCHIVE_EXTRACT_ACL|ARCHIVE_EXTRACT_FFLAGS
           |ARCHIVE_EXTRACT_SECURE_SYMLINKS|ARCHIVE_EXTRACT_SECURE_NODOTDOT;
    if(cm==0)fl|=ARCHIVE_EXTRACT_UNLINK;
    archive_write_disk_set_options(ext,fl);archive_write_disk_set_standard_lookup(ext);
    if(archive_read_open_filename(a,ap.toUtf8().constData(),10240)!=ARCHIVE_OK){
        emit finished(false,"Cannot open: "+QString::fromUtf8(archive_error_string(a)));
        archive_read_free(a);archive_write_free(ext);return;}
    qint64 bo=0,le=0;struct archive_entry*entry;int r;
    while((r=archive_read_next_header(a,&entry))==ARCHIVE_OK||r==ARCHIVE_WARN){
        if(m_cancelRequested.loadAcquire()){archive_read_free(a);archive_write_free(ext);emit finished(false,"Cancelled");return;}
        const char*n=archive_entry_pathname_utf8(entry);if(!n)n=archive_entry_pathname(entry);
        QString ep=n?QString::fromUtf8(n):QString();
        while(ep.startsWith('/'))ep=ep.mid(1);ep.replace("../","");if(ep.isEmpty())continue;
        QString fp=dp+"/"+ep;bool id=(archive_entry_filetype(entry)==AE_IFDIR);
        qint64 es=archive_entry_size_is_set(entry)?archive_entry_size(entry):0;
        if(!id&&QFile::exists(fp)){
            if(cm==1){archive_read_data_skip(a);bo+=es;emit progress(ts>0?qMin(0.99,(qreal)bo/ts):-1.0,ep+" (skipped)");continue;}
            if(cm==2){QFileInfo fi(fp);QString d=fi.absolutePath(),b=fi.completeBaseName(),s=fi.suffix();int nn=1;
                while(QFile::exists(fp)){fp=s.isEmpty()?d+"/"+b+" ("+QString::number(nn)+")":d+"/"+b+" ("+QString::number(nn)+")."+s;nn++;}}}
        archive_entry_set_pathname(entry,fp.toUtf8().constData());
        emit progress(ts>0?qMin(0.99,(qreal)bo/ts):-1.0,ep);
        r=archive_write_header(ext,entry);if(r<ARCHIVE_WARN)continue;
        if(es>0){const void*buf;size_t sz;la_int64_t off;
            while(archive_read_data_block(a,&buf,&sz,&off)==ARCHIVE_OK){
                if(m_cancelRequested.loadAcquire()){archive_read_free(a);archive_write_free(ext);emit finished(false,"Cancelled");return;}
                archive_write_data_block(ext,buf,sz,off);bo+=(qint64)sz;
                if(ts>0&&(bo-le)>=256*1024){emit progress(qMin(0.99,(qreal)bo/ts),ep);le=bo;}}}
        archive_write_finish_entry(ext);}
    archive_read_free(a);archive_write_free(ext);
    bool ok=(r==ARCHIVE_EOF);emit progress(1.0,"Complete");emit finished(ok,ok?QString():"Extraction error");}

void ArchiveWorker::create(const QString &op,const QStringList &sp,const QString &fmt){
    m_cancelRequested.storeRelease(0);
    auto*a=archive_write_new();QString f=fmt.toLower();
    if(f=="tar.gz"||f=="tgz"){archive_write_add_filter_gzip(a);archive_write_set_format_pax_restricted(a);}
    else if(f=="tar.bz2"){archive_write_add_filter_bzip2(a);archive_write_set_format_pax_restricted(a);}
    else if(f=="tar.xz"){archive_write_add_filter_xz(a);archive_write_set_format_pax_restricted(a);}
    else if(f=="tar"){archive_write_add_filter_none(a);archive_write_set_format_pax_restricted(a);}
    else if(f=="zip"){archive_write_add_filter_none(a);archive_write_set_format_zip(a);}
    else if(f=="7z"){archive_write_add_filter_none(a);archive_write_set_format_7zip(a);}
    else{archive_write_add_filter_gzip(a);archive_write_set_format_pax_restricted(a);}
    if(archive_write_open_filename(a,op.toUtf8().constData())!=ARCHIVE_OK){
        emit finished(false,"Cannot create: "+QString::fromUtf8(archive_error_string(a)));archive_write_free(a);return;}
    struct FE{QString abs,rel;};QVector<FE>all;qint64 tb=0;
    for(const QString&src:sp){QFileInfo fi(src);QString base=fi.absolutePath();
        if(fi.isDir()){all.append({fi.absoluteFilePath(),QDir(base).relativeFilePath(fi.absoluteFilePath())});
            QDirIterator it(src,QDir::Files|QDir::Dirs|QDir::NoDotAndDotDot,QDirIterator::Subdirectories);
            while(it.hasNext()){it.next();all.append({it.filePath(),QDir(base).relativeFilePath(it.filePath())});
                if(it.fileInfo().isFile())tb+=it.fileInfo().size();}}
        else{all.append({fi.absoluteFilePath(),fi.fileName()});tb+=fi.size();}}
    qint64 w=0;char buf[8192];
    for(int i=0;i<all.size();i++){
        if(m_cancelRequested.loadAcquire()){archive_write_close(a);archive_write_free(a);QFile::remove(op);emit finished(false,"Cancelled");return;}
        const auto&fe=all[i];QFileInfo fi(fe.abs);
        emit progress(tb>0?qMin(0.99,(qreal)w/tb):(qreal)i/all.size(),fe.rel);
        auto*entry=archive_entry_new();archive_entry_set_pathname(entry,fe.rel.toUtf8().constData());
        archive_entry_set_mtime(entry,fi.lastModified().toSecsSinceEpoch(),0);
        if(fi.isDir()){archive_entry_set_filetype(entry,AE_IFDIR);archive_entry_set_perm(entry,0755);archive_entry_set_size(entry,0);}
        else{archive_entry_set_filetype(entry,AE_IFREG);archive_entry_set_perm(entry,0644);archive_entry_set_size(entry,fi.size());}
        archive_write_header(a,entry);
        if(fi.isFile()){QFile ff(fe.abs);if(ff.open(QIODevice::ReadOnly)){qint64 len;
            while((len=ff.read(buf,sizeof(buf)))>0){
                if(m_cancelRequested.loadAcquire()){archive_write_close(a);archive_write_free(a);QFile::remove(op);emit finished(false,"Cancelled");return;}
                archive_write_data(a,buf,len);w+=len;}}}
        archive_entry_free(entry);}
    archive_write_close(a);archive_write_free(a);emit progress(1.0,"Complete");emit finished(true,QString());}

// ── Manager ──────────────────────────────────────────────────

ArchiveManager::ArchiveManager(QObject *p):QObject(p){
    qRegisterMetaType<ArchiveEntry>();qRegisterMetaType<QVector<ArchiveEntry>>();
    m_createParentFolder=m_settings.value("createParentFolder",true).toBool();
    m_model=new ArchiveEntryModel(this);m_worker=new ArchiveWorker();
    m_workerThread=new QThread(this);m_worker->moveToThread(m_workerThread);
    connect(m_worker,&ArchiveWorker::progress,this,[this](qreal v,const QString&e){m_progress=v;m_currentEntry=e;emit progressChanged();});
    connect(m_worker,&ArchiveWorker::contentsReady,this,[this](const QVector<ArchiveEntry>&e){m_model->setEntries(e);});
    connect(m_worker,&ArchiveWorker::finished,this,[this](bool ok,const QString&msg){
        if(ok){if(m_status=="loading")setStatus("loaded");
            else if(m_status=="extracting"){setStatus("extracted");emit extractionComplete();}
            else if(m_status=="creating"){setStatus("created");emit creationComplete();}}
        else{if(msg=="Cancelled")setStatus("cancelled");else{setError(msg);setStatus("error");}}
        setBusy(false);});
    m_workerThread->start();}
ArchiveManager::~ArchiveManager(){m_worker->requestCancel();m_workerThread->quit();m_workerThread->wait(5000);delete m_worker;}

QString ArchiveManager::archivePath()const{return m_archivePath;}
QString ArchiveManager::archiveName()const{return m_archivePath.isEmpty()?QString():QFileInfo(m_archivePath).fileName();}
QString ArchiveManager::archiveBaseName()const{return computeBaseName();}
QString ArchiveManager::archiveSize()const{return m_archivePath.isEmpty()?QString():formatBytes(QFileInfo(m_archivePath).size());}
QString ArchiveManager::archiveType()const{
    if(m_archivePath.isEmpty())return{};QString l=m_archivePath.toLower();
    if(l.endsWith(".tar.gz")||l.endsWith(".tgz"))return"TAR.GZ";if(l.endsWith(".tar.bz2")||l.endsWith(".tbz2"))return"TAR.BZ2";
    if(l.endsWith(".tar.xz")||l.endsWith(".txz"))return"TAR.XZ";if(l.endsWith(".tar.zst"))return"TAR.ZSTD";
    if(l.endsWith(".tar"))return"TAR";if(l.endsWith(".zip"))return"ZIP";if(l.endsWith(".7z"))return"7Z";
    if(l.endsWith(".rar"))return"RAR";if(l.endsWith(".gz"))return"GZ";if(l.endsWith(".bz2"))return"BZ2";
    if(l.endsWith(".xz"))return"XZ";if(l.endsWith(".iso"))return"ISO";if(l.endsWith(".cpio"))return"CPIO";
    if(l.endsWith(".deb"))return"DEB";if(l.endsWith(".rpm"))return"RPM";return"Archive";}
QString ArchiveManager::destinationPath()const{return m_destinationPath;}
qreal ArchiveManager::progress()const{return m_progress;}
QString ArchiveManager::currentEntry()const{return m_currentEntry;}
QString ArchiveManager::status()const{return m_status;}
bool ArchiveManager::busy()const{return m_busy;}
QString ArchiveManager::errorMessage()const{return m_errorMessage;}
int ArchiveManager::conflictMode()const{return m_conflictMode;}
int ArchiveManager::operationType()const{return m_operationType;}
bool ArchiveManager::createParentFolder()const{return m_createParentFolder;}
ArchiveEntryModel*ArchiveManager::contents()const{return m_model;}
QStringList ArchiveManager::createFiles()const{return m_createFiles;}
QString ArchiveManager::createFilesSize()const{
    qint64 t=0;for(const auto&f:m_createFiles){QFileInfo fi(f);
        if(fi.isFile())t+=fi.size();else if(fi.isDir()){QDirIterator it(f,QDir::Files,QDirIterator::Subdirectories);
            while(it.hasNext()){it.next();t+=it.fileInfo().size();}}}return formatBytes(t);}

void ArchiveManager::setDestinationPath(const QString&p){
    QString c=p;if(c.startsWith("file://"))c=QUrl(c).toLocalFile();if(m_destinationPath!=c){m_destinationPath=c;emit destinationPathChanged();}}
void ArchiveManager::setConflictMode(int m){if(m_conflictMode!=m){m_conflictMode=m;emit conflictModeChanged();}}
void ArchiveManager::setCreateParentFolder(bool v){
    if(m_createParentFolder!=v){m_createParentFolder=v;m_settings.setValue("createParentFolder",v);emit createParentFolderChanged();}}

void ArchiveManager::setDestinationFolder(const QString &folder){
    QString c=folder;if(c.startsWith("file://"))c=QUrl(c).toLocalFile();
    if(m_createParentFolder&&!m_archivePath.isEmpty()){
        QString bn=computeBaseName();if(!bn.isEmpty())c=c+"/"+bn;}
    setDestinationPath(c);}

QString ArchiveManager::computeBaseName()const{
    if(m_archivePath.isEmpty())return{};QFileInfo fi(m_archivePath);QString b=fi.completeBaseName();
    if(b.endsWith(".tar",Qt::CaseInsensitive))b=b.left(b.length()-4);return b;}

void ArchiveManager::openArchive(const QString&path){
    if(m_busy)return;QString c=path;if(c.startsWith("file://"))c=QUrl(c).toLocalFile();
    if(!QFile::exists(c)){setError("File not found: "+c);setStatus("error");return;}
    m_archivePath=c;m_destinationPath=suggestedDestination();m_progress=0;m_currentEntry.clear();m_model->clear();
    emit archivePathChanged();emit destinationPathChanged();emit progressChanged();
    setStatus("loading");setBusy(true);setError(QString());m_operationType=1;emit operationTypeChanged();
    QMetaObject::invokeMethod(m_worker,"listContents",Qt::QueuedConnection,Q_ARG(QString,c));}

void ArchiveManager::extract(){
    if(m_busy||m_archivePath.isEmpty())return;QDir().mkpath(m_destinationPath);
    setStatus("extracting");setBusy(true);setError(QString());m_progress=0;emit progressChanged();
    m_operationType=1;emit operationTypeChanged();
    QMetaObject::invokeMethod(m_worker,"extract",Qt::QueuedConnection,
        Q_ARG(QString,m_archivePath),Q_ARG(QString,m_destinationPath),Q_ARG(qint64,m_model->totalSize()),Q_ARG(int,m_conflictMode));}

void ArchiveManager::cancel(){m_worker->requestCancel();}

void ArchiveManager::clear(){
    m_archivePath.clear();m_destinationPath.clear();m_progress=0;m_currentEntry.clear();
    m_model->clear();m_errorMessage.clear();m_operationType=0;
    emit archivePathChanged();emit destinationPathChanged();emit progressChanged();
    emit errorChanged();emit operationTypeChanged();setStatus("empty");setBusy(false);}

void ArchiveManager::addFiles(const QStringList&paths){
    for(const QString&p:paths){QString c=p;if(c.startsWith("file://"))c=QUrl(c).toLocalFile();
        if(!m_createFiles.contains(c)&&QFileInfo::exists(c))m_createFiles.append(c);}emit createFilesChanged();}
void ArchiveManager::removeFile(int i){if(i>=0&&i<m_createFiles.size()){m_createFiles.removeAt(i);emit createFilesChanged();}}
void ArchiveManager::clearFiles(){m_createFiles.clear();emit createFilesChanged();
    if(m_operationType==2){m_operationType=0;m_progress=0;m_currentEntry.clear();m_errorMessage.clear();
        emit operationTypeChanged();emit progressChanged();emit errorChanged();
        setStatus(m_archivePath.isEmpty()?"empty":"loaded");setBusy(false);}}

void ArchiveManager::createArchive(const QString&out,const QString&fmt){
    if(m_busy||m_createFiles.isEmpty())return;QString c=out;if(c.startsWith("file://"))c=QUrl(c).toLocalFile();
    setStatus("creating");setBusy(true);setError(QString());m_progress=0;emit progressChanged();
    m_operationType=2;emit operationTypeChanged();
    QMetaObject::invokeMethod(m_worker,"create",Qt::QueuedConnection,
        Q_ARG(QString,c),Q_ARG(QStringList,m_createFiles),Q_ARG(QString,fmt));}

int ArchiveManager::countConflicts()const{
    if(m_archivePath.isEmpty()||m_destinationPath.isEmpty())return 0;int c=0;
    for(int i=0;i<m_model->rowCount();i++){auto idx=m_model->index(i);
        if(m_model->data(idx,ArchiveEntryModel::IsDirRole).toBool())continue;
        QString p=m_model->data(idx,ArchiveEntryModel::PathRole).toString();
        while(p.startsWith('/'))p=p.mid(1);p.replace("../","");
        if(!p.isEmpty()&&QFile::exists(m_destinationPath+"/"+p))c++;}return c;}

bool ArchiveManager::destinationExists()const{
    QDir d(m_destinationPath);return d.exists()&&!d.entryList(QDir::AllEntries|QDir::NoDotAndDotDot).isEmpty();}

QString ArchiveManager::formatBytes(qint64 b){
    if(b<0)return QStringLiteral("\u2014");if(b<1024)return QString::number(b)+" B";
    if(b<1024*1024)return QString::number(b/1024.0,'f',1)+" KB";
    if(b<1024LL*1024*1024)return QString::number(b/(1024.0*1024),'f',1)+" MB";
    return QString::number(b/(1024.0*1024*1024),'f',2)+" GB";}
QStringList ArchiveManager::supportedFormats(){return{"tar.gz","tar.bz2","tar.xz","tar","zip","7z"};}
bool ArchiveManager::fileExists(const QString&p){QString c=p;if(c.startsWith("file://"))c=QUrl(c).toLocalFile();return QFile::exists(c);}
QString ArchiveManager::suggestedDestination()const{
    if(m_archivePath.isEmpty())return{};QFileInfo fi(m_archivePath);
    if(m_createParentFolder){QString bn=computeBaseName();return fi.absolutePath()+"/"+bn;}
    return fi.absolutePath();}
QString ArchiveManager::fileName(const QString&p)const{return QFileInfo(p).fileName();}
QString ArchiveManager::fileSize(const QString&p)const{
    QFileInfo fi(p);if(fi.isDir()){qint64 t=0;QDirIterator it(p,QDir::Files,QDirIterator::Subdirectories);
        while(it.hasNext()){it.next();t+=it.fileInfo().size();}return formatBytes(t);}return formatBytes(fi.size());}
bool ArchiveManager::isDirectory(const QString&p)const{return QFileInfo(p).isDir();}
void ArchiveManager::setStatus(const QString&s){if(m_status!=s){m_status=s;emit statusChanged();}}
void ArchiveManager::setBusy(bool b){if(m_busy!=b){m_busy=b;emit busyChanged();}}
void ArchiveManager::setError(const QString&e){if(m_errorMessage!=e){m_errorMessage=e;emit errorChanged();}}
